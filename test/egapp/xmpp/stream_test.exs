defmodule Egapp.XMPP.StreamTest do
  use ExUnit.Case
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stream

  setup do
    state = %{
      client: %{}
    }
    {:ok, state: state}
  end

  test "stream header has necessary attributes", %{state: state} do
    assert {:ok, resp} = Stream.stream(
      %{"xmlns:stream" => Const.xmlns_stream(), "version" => Const.xmpp_version()},
      state
    )
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream <> ~s(")
    assert resp =~ ~s(stream:features)
    assert resp =~ ~s(mechanisms)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_sasl <> ~s(")
    assert resp =~ ~s(PLAIN)
    assert not (resp =~ ~s(</stream:stream>))
  end

  test "stream header with incorrect version has necessary attributes", %{state: state} do
    assert {:error, resp} = Stream.stream(
      %{"xmlns:stream" => Const.xmlns_stream(), "version" => "0.9"},
      state
    )
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_stream_error <> ~s(")
    assert resp =~ ~s(unsupported-version)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header with incorrect namespace has necessary attributes", %{state: state} do
    assert {:error, resp} = Stream.stream(
      %{"xmlns:stream" => "foo", "version" => Const.xmpp_version()},
      state
    )
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_stream_error <> ~s(")
    assert resp =~ ~s(invalid-namespace)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header without version has necessary attributes", %{state: state} do
    assert {:error, resp} = Stream.stream(
      %{"xmlns:stream" => Const.xmlns_stream()},
      state
    )
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_stream_error <> ~s(")
    assert resp =~ ~s(unsupported-version)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header without namespace has necessary attributes", %{state: state} do
    assert {:error, resp} = Stream.stream(
      %{"version" => Const.xmpp_version()},
      state
    )
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_stream_error <> ~s(")
    assert resp =~ ~s(bad-namespace-prefix)
    assert resp =~ ~s(</stream:stream>)
  end
end
