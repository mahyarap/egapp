defmodule Egapp.XMPP.Stanza do
  @moduledoc """
  This module handles XMPP Stanzas.

  XMPP defines three stanzas: iq, message, presence. In addition, there are
  five common attributes for these stanza types: to, from, id, type, xml:lang.
  """
  alias Egapp.Config
  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Stream

  @iq_types ["get", "set", "result", "error"]

  def iq(%{"to" => to, "type" => type} = attrs, data, state)
      when is_map_key(attrs, "id") and type in @iq_types do
    case Jid.partial_parse(to) do
      %Jid{domainpart: "egapp.im"} ->
        Egapp.XMPP.Server.Stanza.iq(attrs, data, state)

      %Jid{domainpart: "conference.egapp.im"} ->
        Egapp.XMPP.Conference.Stanza.iq(attrs, data, state)
    end
  end

  def iq(%{"type" => type} = attrs, data, state)
      when is_map_key(attrs, "id") and type in @iq_types do
    Egapp.XMPP.Server.Stanza.iq(attrs, data, state)
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
    Egapp.XMPP.Server.Stanza.message(attrs, children, state)
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

  def presence(%{"to" => to} = attrs, child, state) do
    case Jid.parse(to) do
      %Jid{domainpart: "conference.egapp.im"} ->
        Egapp.XMPP.Conference.Stanza.presence(attrs, child, state)

      "egapp.im" ->
        Egapp.XMPP.Server.Stanza.presence(attrs, child, state)
    end
  end

  def presence(attrs, child, state) when not is_map_key(attrs, "to") do
    Egapp.XMPP.Server.Stanza.presence(attrs, child, state)
  end

  def presence_template(%{from: from, to: to}, content) do
    {:presence, [from: from, to: to], content}
  end
end
