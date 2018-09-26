defmodule Tus.Router do
  use Plug.Router

  ##############################################################################
  # SETTINGS
  #
  #

  @versions ["1.0.0"]
  @max_chunk_size 8_000_000

  ##############################################################################
  # PLUGS
  #
  #
  plug(Plug.Logger)
  plug(:protocol_version)
  plug(:extentions)
  plug(:match)
  plug(:dispatch)

  ##############################################################################
  # CORE
  #
  #

  ## HEAD
  match "/:file", via: :head do
    # Prevent caching
    conn = put_resp_header(conn, "cache-control", "no-store")

    try do
      upload =
        file
        |> Tus.UploadServer.via()
        |> Tus.UploadServer.read()

      conn
      |> put_offset(upload)
      |> put_length_if_available(upload)
      |> send_resp(200, "")
    catch
      :exit, _reason -> send_resp(conn, :not_found, "")
    end
  end

  ## PATCH
  patch "/:file" do
    patch_upload(conn, get_req_header(conn, "content-type"))
  end

  defp patch_upload(conn, content_type) when content_type == ["application/offset+octet-stream"] do
    {:ok, body, _} = read_body(conn, limit: @max_chunk_size)

    try do
      reply =
        conn.params["file"]
        |> Tus.UploadServer.via()
        |> Tus.UploadServer.append(read_offset(conn), body)

      case reply do
        {:ok, upload} ->
          conn
          |> put_offset(upload)
          |> put_length_if_available(upload)
          |> send_resp(:no_content, "")

        {:error, :offset_mismatch} ->
          send_resp(conn, :conflict, "")
      end
    catch
      :exit, _reason -> send_resp(conn, :not_found, "")
    end
  end

  defp patch_upload(conn, _) do
    send_resp(conn, :unsupported_media_type, "")
  end

  ## OPTIONS
  options "/" do
    send_resp(conn, :no_content, "")
  end

  ##############################################################################
  # CREATION
  #
  #

  ## POST

  post "/" do
    id = upload_id(conn)
    length = upload_length(conn)

    case trigger_creation(id, length, conn.private.tus_extentions) do
      {:ok, upload, save} ->
        upload = %{upload | metadata: parse_metadata(conn)}
        save.(upload)

        conn
        |> assign(:upload, upload)
        |> put_resp_header("location", "/#{upload.id}")
        |> send_resp(201, "")

      {:error, {:noext, :creation}} ->
        send_resp(conn, :not_implemented, "")

      {:error, {:noext, :creation_defer_length}} ->
        send_resp(conn, :not_implemented, "")
    end
  end

  defp parse_metadata(conn) do
    conn
    |> get_req_header("upload-metadata")
    |> Enum.map(fn value ->
      [key, value] = String.split(value)
      {key, Base.decode64!(value)}
    end)
  end

  def upload_length(conn) do
    with [] <- get_req_header(conn, "upload-length") do
      # Only allowed option left
      ["1"] = get_req_header(conn, "upload-defer-length")
      :deferred
    else
      [bin] -> {:length, String.to_integer(bin)}
    end
  end

  def upload_id(conn) do
    case get_req_header(conn, "test-resource-name") do
      [name] -> name
      _ -> :crypto.strong_rand_bytes(10) |> Base.encode32()
    end
  end

  defp trigger_creation(id, length, extentions) do
    case {:creation in extentions, :creation_defer_length in extentions, length} do
      {false, _, _} -> {:error, {:noext, :creation}}
      {_, false, :deferred} -> {:error, {:noext, :creation_defer_length}}
      _ -> create(id, length)
    end
  end

  defp create(id, length) do
    upload =
      case length do
        {:length, length} -> %Tus.Upload{length: length}
        :deferred -> %Tus.Upload{deferred_length: true}
      end

    upload = %{upload | id: id}

    save = fn upload ->
      {:ok, _pid} =
        case Tus.UploadSupervisor.create_upload(upload) do
          {:error, {:already_started, pid}} -> {:ok, pid}
          value -> value
        end
    end

    {:ok, upload, save}
  end

  ##############################################################################
  # FALLBACK
  #
  #

  match "/" do
    send_resp(conn, 404, "oops")
  end

  match "/*_rest" do
    send_resp(conn, 404, "oops")
  end

  ##############################################################################
  # PLUGS + HELPERS
  #
  #
  def protocol_version(%{method: "OPTIONS"} = conn, _) do
    set_protocol_version(conn, @versions |> List.first())
  end

  def protocol_version(conn, _) do
    case get_req_header(conn, "tus-resumable") do
      [version] when version in @versions ->
        set_protocol_version(conn, version)

      _ ->
        conn
        |> send_resp(:precondition_failed, "")
        |> halt()
    end
  end

  defp set_protocol_version(conn, version) do
    conn
    |> put_private(:tus_version, version)
    |> put_resp_header("tus-resumable", version)
    |> put_resp_header("tus-version", Enum.join(@versions, ","))
    |> put_resp_header("tus-max-size", @max_chunk_size |> to_string)
  end

  def extentions(conn, _) do
    default = [
      :creation,
      :creation_defer_length,
      # :expiration,
      # :checksum,
      # :checksum_trailer,
      :termination
      # :concatenation,
      # :concatenation_unfinished
    ]

    extentions = Application.get_env(:tus, :extentions, default)

    conn
    |> put_private(:tus_extentions, extentions)
    |> register_before_send(&extention_header/1)
  end

  defp extention_header(conn) do
    case conn.private.tus_extentions do
      [] -> conn
      list -> put_resp_header(conn, "tus-extension", Enum.join(list, ","))
    end
  end

  defp read_offset(conn) do
    [offset] = get_req_header(conn, "upload-offset")
    offset |> String.to_integer()
  end

  defp put_offset(conn, upload) do
    put_resp_header(conn, "upload-offset", Integer.to_string(upload.offset))
  end

  defp put_length_if_available(conn, %{length: length}) do
    case length do
      :unknown -> conn
      length -> put_resp_header(conn, "upload-length", Integer.to_string(length))
    end
  end
end
