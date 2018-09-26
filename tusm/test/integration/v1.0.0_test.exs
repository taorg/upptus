defmodule Tus.Integration.V1_0_0Test do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Tus.{Router, Upload, UploadSupervisor}

  @opts Router.init([])

  setup do
    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(UploadSupervisor) do
        DynamicSupervisor.terminate_child(UploadSupervisor, pid)
      end
    end)
  end

  defp build_conn(method, path, params_or_body \\ nil) do
    conn(method, path, params_or_body)
    |> put_req_header("tus-resumable", "1.0.0")
  end

  describe "core protocol - head" do
    test "known file of unknown length" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn = build_conn(:head, "/test")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 200
      assert ["0"] = get_resp_header(conn, "upload-offset")
      assert [] = get_resp_header(conn, "upload-length")
    end

    test "known file of known length" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "known", length: 100})
      conn = build_conn(:head, "/known")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert ["100"] = get_resp_header(conn, "upload-length")
    end

    test "unknown file" do
      conn = build_conn(:head, "/unavailable")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 404
      assert [] = get_resp_header(conn, "upload-offset")
    end
  end

  describe "core protocol - patch" do
    test "patch file of unknown length" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn =
        build_conn(:patch, "/test", "content")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("content-type", "application/offset+octet-stream")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 204
      assert ["7"] = get_resp_header(conn, "upload-offset")
      assert [] = get_resp_header(conn, "upload-length")
    end

    test "patch data is persisted" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn =
        build_conn(:patch, "/test", "content")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("content-type", "application/offset+octet-stream")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      conn = build_conn(:head, "/test", "")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 200
      assert ["7"] = get_resp_header(conn, "upload-offset")
    end

    test "fail for non-matching upload-offset" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn =
        build_conn(:patch, "/test", "content")
        |> put_req_header("upload-offset", "1")
        |> put_req_header("content-type", "application/offset+octet-stream")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 409
      assert [] = get_resp_header(conn, "upload-offset")
      assert [] = get_resp_header(conn, "upload-length")
    end

    test "fail for incorrect content type" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn =
        build_conn(:patch, "/test", "content")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("content-type", "application/pdf")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 415
    end

    test "fail for to long" do
      Tus.UploadSupervisor.create_upload(%Upload{id: "test"})

      conn =
        build_conn(:patch, "/test", "content")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("content-type", "application/pdf")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 415
    end
  end

  describe "extention creation - post" do
    test "create for known length" do
      conn =
        build_conn(:post, "/", "")
        |> put_req_header("upload-length", "100")
        |> put_req_header("test-resource-name", "create-known-length")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 201
      assert ["/create-known-length"] = get_resp_header(conn, "location")

      upload = conn.assigns.upload

      assert upload.length == 100
      refute upload.deferred_length
    end

    test "create for unknown length" do
      conn =
        build_conn(:post, "/", "")
        |> put_req_header("upload-defer-length", "1")
        |> put_req_header("test-resource-name", "create-known-length")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 201
      assert ["/create-known-length"] = get_resp_header(conn, "location")

      upload = conn.assigns.upload

      assert upload.length == :unknown
      assert upload.deferred_length
    end

    test "created file is persistent" do
      conn =
        build_conn(:post, "/", "")
        |> put_req_header("upload-length", "100")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      [url] = get_resp_header(conn, "location")

      conn = build_conn(:head, url, "")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.status == 200
      assert ["0"] = get_resp_header(conn, "upload-offset")
      assert ["100"] = get_resp_header(conn, "upload-length")
    end
  end
end
