defmodule Tus.IntegrationTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Tus.{Router, Upload, UploadSupervisor}

  @opts Router.init([])

  describe "version" do
    test "no version - option request" do
      conn = conn(:options, "/")

      # Invoke the plug
      conn = Router.call(conn, @opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 204
      assert ["1.0.0"] = get_resp_header(conn, "tus-resumable")
      assert ["1.0.0"] = get_resp_header(conn, "tus-version")
      assert ["8000000"] = get_resp_header(conn, "tus-max-size")
    end
  end
end
