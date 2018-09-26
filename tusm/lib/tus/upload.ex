defmodule Tus.Upload do
  defstruct id: nil,
            content: "",
            offset: 0,
            length: :unknown,
            deferred_length: false,
            metadata: []

  def append(%__MODULE__{} = upload, data) do
    new_content = upload.content <> data
    new_offset = upload.offset + byte_size(data)

    %{upload | content: new_content, offset: new_offset}
  end

  def valid?(%__MODULE__{} = upload) do
    upload.length == :unknown or upload.length >= upload.offset
  end

  def finished?(%__MODULE__{} = upload) do
    upload.length == upload.offset
  end
end
