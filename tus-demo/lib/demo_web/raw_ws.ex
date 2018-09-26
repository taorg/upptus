defmodule DemoWeb.RawWebSocket do

  use Phoenix.Socket
  require Logger
  transport(:api, PhxRaws.Transports)

  def connect(_params, socket) do
    send(self(), {:text, "Welcome!"})
    Logger.debug("connect-------------------------------- #{inspect(socket)}")
    {:ok, socket}
  end

  @spec id(any()) :: nil
  def id(socket), do: nil

  @spec handle(:closed | :text, any(), any()) :: any()
  def handle(:text, message, state) do
    Logger.debug("--------message------- #{inspect(message)}--------state--------- #{inspect(state)}")
    # | :ok
    # | state
    # | {:text, message}
    # | {:text, message, state}
    # | {:close, "Goodbye!"}
    {:text, message}
  end

  def handle(:closed, reason, _state) do
    IO.inspect(reason)
  end
end
