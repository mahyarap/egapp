defmodule Egapp.XMPP.StreamTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Stream

  setup do
    {:ok, state: %{to: self(), client: %{is_authenticated: false}}}
  end

  describe "stream header" do
    test "when not authenticated", %{state: state} do
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
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:features)
      assert resp =~ ~s(mechanisms)
      refute resp =~ ~s(</stream:stream>)
    end

    test "when authenticated", %{state: state} do
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
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:features)
      refute resp =~ ~s(mechanisms)
      assert resp =~ ~s(bind)
      assert resp =~ ~s(session)
      refute resp =~ ~s(</stream:stream>)
    end

    test "with incorrect version returns unsupported-version", %{state: state} do
      attrs = %{"xmlns:stream" => Const.xmlns_stream(), "version" => "0.9"}
      assert {:error, resp} = Stream.stream(attrs, state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<?xml version="1.0"?>)
      assert resp =~ ~s(stream:stream)
      assert resp =~ ~s(from="egapp.im")
      assert resp =~ ~r/id="[0-9]{8}"/
      assert resp =~ ~s(version="1.0")
      assert resp =~ ~s(xml:lang="en")
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:error)
      assert resp =~ ~s(unsupported-version)
      assert resp =~ ~s(</stream:stream>)
    end

    test "with incorrect namespace returns invalid-namespace", %{state: state} do
      attrs = %{"xmlns:stream" => "foo", "version" => Const.xmpp_version()}
      assert {:error, resp} = Stream.stream(attrs, state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<?xml version="1.0"?>)
      assert resp =~ ~s(stream:stream)
      assert resp =~ ~s(from="egapp.im")
      assert resp =~ ~r/id="[0-9]{8}"/
      assert resp =~ ~s(version="1.0")
      assert resp =~ ~s(xml:lang="en")
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:error)
      assert resp =~ ~s(invalid-namespace)
      assert resp =~ ~s(</stream:stream>)
    end

    test "without version returns unsupported-version", %{state: state} do
      attrs = %{"xmlns:stream" => Const.xmlns_stream()}
      assert {:error, resp} = Stream.stream(attrs, state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<?xml version="1.0"?>)
      assert resp =~ ~s(stream:stream)
      assert resp =~ ~s(from="egapp.im")
      assert resp =~ ~r/id="[0-9]{8}"/
      assert resp =~ ~s(version="1.0")
      assert resp =~ ~s(xml:lang="en")
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:error)
      assert resp =~ ~s(unsupported-version)
      assert resp =~ ~s(</stream:stream>)
    end

    test "without namespace returns bad-namespace-prefix", %{state: state} do
      attrs = %{"version" => Const.xmpp_version()}
      assert {:error, resp} = Stream.stream(attrs, state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<?xml version="1.0"?>)
      assert resp =~ ~s(stream:stream)
      assert resp =~ ~s(from="egapp.im")
      assert resp =~ ~r/id="[0-9]{8}"/
      assert resp =~ ~s(version="1.0")
      assert resp =~ ~s(xml:lang="en")
      assert resp =~ ~s(xmlns="#{Const.xmlns_c2s()}")
      assert resp =~ ~s(xmlns:stream="#{Const.xmlns_stream()}")
      assert resp =~ ~s(stream:error)
      assert resp =~ ~s(bad-namespace-prefix)
      assert resp =~ ~s(</stream:stream>)
    end
  end

  defmodule SASLPlainStub do
    @behaviour Egapp.SASL

    def type, do: :plain

    def authenticate("pass"), do: {:ok, %{username: "foo", id: 1}}

    def authenticate("nopass"), do: {:error, %{}}
  end

  defmodule JidConnRegistryStub do
    @behaviour Egapp.JidConnRegistry

    def put(_key, _val), do: nil

    def match(_key), do: nil
  end

  describe "auth" do
    setup do
      [attrs: %{"xmlns" => Const.xmlns_sasl()}]
    end

    test "with plain mech when auth suceeds", %{attrs: attrs, state: state} do
      attrs = Map.put(attrs, "mechanism", "PLAIN")

      state =
        state
        |> Map.put(:sasl_mechanisms, [SASLPlainStub])
        |> Map.put(:jid_conn_registry, JidConnRegistryStub)

      assert %{client: %{is_authenticated: false}} = state

      assert {:ok, resp, new_state} = Stream.auth(attrs, [xmlcdata: "pass"], state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<success)
      assert %{client: %{is_authenticated: true}} = new_state
      assert %{client: %{id: id}} = new_state
      assert is_integer(id)
      assert %{client: %{jid: jid}} = new_state
      assert jid.localpart == "foo"
      assert jid.domainpart == Egapp.Config.get(:domain_name)
      assert jid.resourcepart |> String.to_integer() |> is_integer()
    end

    test "with plain mech when auth fails", %{attrs: attrs, state: state} do
      attrs = Map.put(attrs, "mechanism", "PLAIN")

      state =
        state
        |> Map.put(:sasl_mechanisms, [SASLPlainStub])
        |> Map.put(:jid_conn_registry, JidConnRegistryStub)

      assert %{client: %{is_authenticated: false}} = state

      assert {:retry, resp, new_state} = Stream.auth(attrs, [xmlcdata: "nopass"], state)
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<failure)
      assert %{client: %{is_authenticated: false}} = new_state
      refute get_in(new_state, [:client, :id])
      refute get_in(new_state, [:client, :jid])
    end
  end

  describe "manual stream error creation" do
    test "bad-namespace-prefix" do
      resp =
        Stream.bad_namespace_prefix_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<bad-namespace-prefix)
      refute resp =~ ~s(</stream:stream>)
    end

    test "bad-format" do
      resp =
        Stream.bad_format_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<bad-format)
      refute resp =~ ~s(</stream:stream>)
    end

    test "not-well-formed" do
      resp =
        Stream.not_well_formed_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<not-well-formed)
      refute resp =~ ~s(</stream:stream>)
    end

    test "not-authorized-error" do
      resp =
        Stream.not_authorized_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<not-authorized)
      refute resp =~ ~s(</stream:stream>)
    end

    test "invalid-namespace" do
      resp =
        Stream.invalid_namespace_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<invalid-namespace)
      refute resp =~ ~s(</stream:stream>)
    end

    test "invalid-xml" do
      resp =
        Stream.invalid_xml_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<invalid-xml)
      refute resp =~ ~s(</stream:stream>)
    end

    test "invalid-mechanism" do
      resp =
        Stream.invalid_mechanism_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<invalid-mechanism)
      refute resp =~ ~s(</stream:stream>)
    end

    test "invalid-version" do
      resp =
        Stream.unsupported_version_error()
        |> :xmerl.export_simple_element(:xmerl_xml)
        |> IO.chardata_to_string()

      refute resp =~ ~s(<?xml version="1.0"?>)
      refute resp =~ ~s(<stream:stream)
      assert resp =~ ~s(<stream:error>)
      assert resp =~ ~s(<unsupported-version)
      refute resp =~ ~s(</stream:stream>)
    end
  end

  test "stream end" do
    assert ['</stream:stream>'] = Stream.stream_end()
  end
end
