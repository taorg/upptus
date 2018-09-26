defmodule Tus.UploadServer do
  use GenServer

  # Client

  def start_link(upload) do
    GenServer.start_link(__MODULE__, upload, name: via(upload))
  end

  def init(args), do: {:ok, args}

  def via(%{id: id}), do: via(id)
  def via(id), do: {:via, Registry, {Tus.UploadRegistry, id}}

  def read(pid) do
    GenServer.call(pid, :read)
  end

  def append(pid, offset, data) do
    GenServer.call(pid, {:append, offset, data})
  end

  def handle_call(:read, _from, upload) do
    {:reply, upload, upload}
  end

  def handle_call({:append, offset, data}, _from, upload) do
    if offset == upload.offset do
      new = Tus.Upload.append(upload, data)

      if Tus.Upload.valid?(new) do
        {:reply, {:ok, new}, new}
      else
        {:reply, {:error, :data_to_long}, upload}
      end
    else
      {:reply, {:error, :offset_mismatch}, upload}
    end
  end
end
