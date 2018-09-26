defmodule Tus.Storage.S3 do
  @moduledoc """
  S3 (or compatible) storage backend for the [Tus server](https://hex.pm/packages/tus)

  ## Installation

  The package can be installed by adding `tus_cache_redis` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:tus, "~> 0.1.1"},
      {:tus_storage_s3, "~> 0.1.0"},
    ]
  end
  ```

  ## Configuration

  - `storage`: Set it as `Tus.Storage.S3`
  - `s3_bucket`: The name of your bucket

  - `s3_host`: Optional. "s3.amazonaws.com" by default
  - `s3_prefix`: Optional. Prefix added to all files. Empty by default
  - `s3_min_part_size`: The minimum size of a single part (except the last).
    In Amazon S3 this is 5MB. For other, compatible services, you might want/need to
    change this restriction.

  In order to allow this backend to function properly, the user accessing the bucket must have at least the
  following AWS IAM policy permissions for the bucket and all of its subresources:

  ```
  s3:AbortMultipartUpload
  s3:DeleteObject
  s3:GetObject
  s3:ListMultipartUploadParts
  s3:PutObject
  ```

  Furthermore, this uses the ExAWS package, so you'll need to add valid AWS keys to its config.

  ```elixir
  config :ex_aws,
    access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
    secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
  ```

  This means it will try to resolve credentials in this order

  - a. Look for the AWS standard AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  - b. Resolve credentials with IAM

  Consult the (ExAWS documentation)[https://hexdocs.pm/ex_aws/ExAws.html#module-aws-key-configuration] for more details.
  """
  alias ExAws.S3

  @default_host "s3.amazonaws.com"
  @default_min_part_size 5 * 1024 * 1024

  defp file_path(config, file) do
    Enum.join(
      [
        config
        |> Map.get(:s3_prefix, "")
        |> String.trim("/"),
        file.uid
      ],
      "/"
    )
    |> String.trim("/")
  end

  defp host(config) do
    config |> Map.get(:s3_host, @default_host)
  end

  defp min_part_size(config) do
    config |> Map.get(:s3_min_part_size, @default_min_part_size)
  end

  defp last_part?(file, part_size) do
    file.offset + part_size >= file.size
  end

  defp part_too_small?(file, config, part_size) do
    if last_part?(file, part_size) do
      false
    else
      min_size = min_part_size(config)
      part_size < min_size && file.offset + min_size > file.size
    end
  end

  @doc """
  Start a [Multipart Upload](http://docs.aws.amazon.com/AmazonS3/latest/dev/uploadobjusingmpu.html)
  and store its `upload_id`.
  """
  def create(file, config) do
    host = host(config)
    file_path = file_path(config, file)

    %{bucket: config.s3_bucket, path: file_path, opts: [], upload_id: nil}
    |> S3.Upload.initialize(host: host)
    |> case do
      {:ok, rs} ->
        %Tus.File{file | upload_id: rs.upload_id, path: file_path}

      err ->
        {:error, err}
    end
  end

  @doc """
  Add data to an already started [Multipart Upload](http://docs.aws.amazon.com/AmazonS3/latest/dev/uploadobjusingmpu.html)
  (identified by `file.upload_id`).

  Amazon restrict the minimum size of a single part (except the last one) to
  at least 5MB. If the data is smaller than that, this function returns `:too_small`.

  That limit can be customized with the config option `s3_min_part_size`.
  """
  def append(file, config, body) do
    part_size = byte_size(body)

    if part_too_small?(file, config, part_size) do
      :too_small
    else
      append_data(file, config, body, part_size)
    end
  end

  defp append_data(file, config, body, part_size) do
    part_id = div(file.offset, min_part_size(config)) + 1

    config.s3_bucket
    |> S3.upload_part(file.path, file.upload_id, part_id, body, "Content-Length": part_size)
    |> ExAws.request(host: host(config))
    |> case do
      {:ok, %{headers: headers}} ->
        {_, etag} = Enum.find(headers, fn {k, _v} -> String.downcase(k) == "etag" end)
        file = %Tus.File{file | parts: file.parts ++ [{part_id, etag}]}
        {:ok, file}

      error ->
        {:error, error}
    end
  end

  @doc """
  Finish a Multipart Upload
  """
  def complete_upload(file, config) do
    config.s3_bucket
    |> ExAws.S3.complete_multipart_upload(file.path, file.upload_id, file.parts)
    |> ExAws.request(host: host(config))
  end

  @doc """
  Delete an uploaded object
  """
  def delete(file, config) do
    ""
    |> ExAws.S3.delete_object(file_path(config, file))
    |> ExAws.request(host: host(config))
  end
end
