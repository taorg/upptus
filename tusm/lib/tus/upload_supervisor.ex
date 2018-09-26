defmodule Tus.UploadSupervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_upload(upload) do
    DynamicSupervisor.start_child(__MODULE__, {Tus.UploadServer, upload})
  end
end
