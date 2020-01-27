defmodule Egapp.Parser.XML.EventManTest do
  use ExUnit.Case, async: true
  require Egapp.Constants, as: Const

  setup do
    pid = start_supervised!({Egapp.Parser.XML.EventMan, to: self(), mod: Kernel})
    {:ok, event_man: pid}
  end

  test "returns :continue with correct input", %{event_man: event_man} do
    attrs = %{
      "version" => Const.xmpp_version(),
      "xmlns:stream" => Const.xmlns_stream()
    }

    assert :continue = GenServer.call(event_man, {"stream:stream", attrs})
    assert_received resp
    assert not Enum.empty?(resp)
  end

  test "exits with incorrect input", %{event_man: event_man} do
    attrs = %{
      "xmlns:stream" => Const.xmlns_stream()
    }

    catch_exit(GenServer.call(event_man, {"stream:stream", attrs}))
    assert_received resp
    assert not Enum.empty?(resp)
  end

  test "exits with incorrect stream prefix", %{event_man: event_man} do
    attrs = %{
      "version" => Const.xmpp_version(),
      "xmlns:stream" => Const.xmlns_stream()
    }

    catch_exit(GenServer.call(event_man, {"stream", attrs}))
    assert_received resp
    assert not Enum.empty?(resp)
  end

  test "returns :continue with correct iq", %{event_man: event_man} do
    attrs = %{"type" => "get"}
    data = [{:xmlel, "ping", %{"xmlns" => Const.xmlns_ping()}, []}]
    assert :continue = GenServer.call(event_man, {"iq", attrs, data})
    assert_received resp
    assert not Enum.empty?(resp)
  end
end
