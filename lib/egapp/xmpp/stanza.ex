defmodule Egapp.XMPP.Stanza do
  @moduledoc """
  This module handles XMPP Stanzas.

  XMPP defines three stanzas: iq, message, presence. In addition, there are
  five common attributes for these stanza types: to, from, id, type, xml:lang.
  """
  alias Egapp.Config
  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Element

  @iq_types ["get", "set", "result", "error"]

  def iq(%{"type" => type} = attrs, data, state)
      when is_map_key(attrs, "id") and is_map_key(attrs, "to") and type in @iq_types do
    do_stanza(:iq, attrs, data, state)
  end

  def iq(%{"type" => type} = attrs, data, state)
      when is_map_key(attrs, "id") and type in @iq_types do
    case get_default_stanza_mod(Map.get(state, :services)) do
      stanza_mod when not is_nil(stanza_mod) ->
        stanza_mod.iq(attrs, data, state)

      _ ->
        content = Element.service_unavailable_error(:cancel)

        resp =
          iq_template(build_iq_attrs(attrs, :error, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {:error, [{state.to, resp}]}
    end
  end

  def iq(attrs, _data, state) do
    {:error, [{state.to, Stream.error(:invalid_xml, attrs, state)}]}
  end

  def iq_template(%{id: id, type: type, from: from}, content) do
    iq_attrs = [
      id: id,
      type: type
    ]

    attrs = if from, do: [{:from, from} | iq_attrs], else: iq_attrs
    content = if content, do: [content], else: []

    {:iq, attrs, content}
  end

  def build_iq_attrs(attrs, type, state) do
    type =
      case type do
        :ok -> 'result'
        :error -> 'error'
      end

    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "to") || Config.get(:domain_name),
      type: type
    }
  end

  def message(%{"type" => "chat"} = attrs, children, state) do
    case get_default_stanza_mod(Map.get(state, :services)) do
      stanza_mod when not is_nil(stanza_mod) ->
        stanza_mod.message(attrs, children, state)

      _ ->
        content = Element.service_unavailable_error(:cancel)

        resp =
          iq_template(build_iq_attrs(attrs, :error, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {:error, [{state.to, resp}]}
    end
  end

  def build_message_attrs(attrs, _state) do
    %{
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "from"),
      to: Map.get(attrs, "to"),
      type: Map.get(attrs, "type")
    }
  end

  def message_template(%{id: id, to: to, from: from, type: type}, data) do
    iq_attrs = [
      id: id,
      from: from,
      to: to,
      type: type
    ]

    {:message, iq_attrs, data}
  end

  def presence(attrs, child, state) when is_map_key(attrs, "to") do
    do_stanza(:presence, attrs, child, state)
  end

  def presence(attrs, child, state) when not is_map_key(attrs, "to") do
    Egapp.XMPP.Server.Stanza.presence(attrs, child, state)
  end

  def presence_template(%{from: from, to: to}, content) do
    {:presence, [from: from, to: to], content}
  end

  defp get_default_stanza_mod(services) do
    with mod when is_atom(mod) and not is_nil(mod) <-
           Kernel.||(services, Config.get(:services))
           |> Enum.find(fn service ->
             service.category() == :server && service.type() == :im
           end) do
      mod.stanza_mod()
    end
  end

  defp do_stanza(stanza, %{"to" => to} = attrs, data, state) do
    services = Map.get(state, :services) || Config.get(:services)

    mod =
      services
      |> Enum.filter(fn mod ->
        to_domainpart =
          to
          |> Jid.partial_parse()
          |> Map.fetch!(:domainpart)

        mod_domainpart =
          mod.address()
          |> Jid.partial_parse()
          |> Map.fetch!(:domainpart)

        match?(^to_domainpart, mod_domainpart)
      end)
      |> Enum.map(fn mod -> mod.stanza_mod() end)
      |> List.first()

    if mod do
      apply(mod, stanza, [attrs, data, state])
    else
      content = Element.service_unavailable_error(:cancel)

      resp =
        iq_template(build_iq_attrs(attrs, :error, state), content)
        |> :xmerl.export_simple_element(:xmerl_xml)

      {:ok, [{state.to, resp}]}
    end
  end
end
