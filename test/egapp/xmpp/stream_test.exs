defmodule Egapp.XMPP.StreamTest do
  use ExUnit.Case, async: true
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stream

  setup do
    state = %{
      client: %{}
    }

    {:ok, state: state}
  end

  test "stream header has necessary attributes", %{state: state} do
    attrs = %{
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert {:ok, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:features)
    assert resp =~ ~s(mechanisms)
    assert not (resp =~ ~s(</stream:stream>))
  end

  test "stream header when authenticated", %{state: state} do
    attrs = %{
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    state = put_in(state, [:client, :is_authenticated], true)
    assert {:ok, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:features)
    assert not (resp =~ ~s(mechanisms))
    assert resp =~ ~s(bind)
    assert resp =~ ~s(session)
    assert not (resp =~ ~s(</stream:stream>))
  end

  test "stream header with incorrect version returns unsupported-version", %{state: state} do
    attrs = %{"xmlns:stream" => Const.xmlns_stream(), "version" => "0.9"}
    assert {:error, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(unsupported-version)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header with incorrect namespace returns invalid-namespace", %{state: state} do
    attrs = %{"xmlns:stream" => "foo", "version" => Const.xmpp_version()}
    assert {:error, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(invalid-namespace)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header without version returns unsupported-version", %{state: state} do
    attrs = %{"xmlns:stream" => Const.xmlns_stream()}
    assert {:error, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(unsupported-version)
    assert resp =~ ~s(</stream:stream>)
  end

  test "stream header without namespace returns bad-namespace-prefix", %{state: state} do
    attrs = %{"version" => Const.xmpp_version()}
    assert {:error, resp} = Stream.stream(attrs, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(bad-namespace-prefix)
    assert resp =~ ~s(</stream:stream>)
  end

  test "manually creating errors", %{state: state} do
    resp =
      Stream.error(:bad_namespace_prefix, %{}, state)
      |> IO.chardata_to_string()

    assert resp =~ ~s(<?xml version="1.0"?>)
    assert resp =~ ~s(stream:stream)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ ~r/id="[0-9]{8}"/
    assert resp =~ ~s(version="1.0")
    assert resp =~ ~s(xml:lang="en")
    assert resp =~ ~s(xmlns=") <> Const.xmlns_c2s() <> ~s(")
    assert resp =~ ~s(xmlns:stream=") <> Const.xmlns_stream() <> ~s(")
    assert resp =~ ~s(stream:error)
    assert resp =~ ~s(bad-namespace-prefix)
    assert resp =~ ~s(</stream:stream>)
  end
end
