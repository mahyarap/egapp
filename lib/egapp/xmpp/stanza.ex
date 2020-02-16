defmodule Egapp.XMPP.Stanza do
  @moduledoc """
  This module handles XMPP Stanzas.

  XMPP defines three stanzas: iq, message, presence. In addition, there are
  five common attributes for these stanza types: to, from, id, type, xml:lang.
  """

  require Ecto.Query

  alias Egapp.Config
  alias Egapp.XMPP.Jid
  alias Egapp.JidConnRegistry

  def iq(%{"to" => to} = attrs, data, state) do
    case Jid.partial_parse(to) do
      %Jid{domainpart: "egapp.im"} ->
        Egapp.XMPP.Server.Stanza.iq(attrs, data, state)

      %Jid{domainpart: "conference.egapp.im"} ->
        Egapp.XMPP.Conference.Stanza.iq(attrs, data, state)
    end
  end

  def iq(attrs, data, state) do
    Egapp.XMPP.Server.Stanza.iq(attrs, data, state)
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

  @doc """
  Handles initial presence (a presence without the `to` attribute).
  """
  def presence(attrs, _child, state) when not is_map_key(attrs, "to") do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    presence_probes = create_presence_probe(roster.users, state)
    initial_presences = create_initial_presence(roster.users, state)
    presence_probes ++ initial_presences
  end

  defp create_initial_presence(users, state) do
    users
    |> Enum.map(fn contact ->
      pattern = %Jid{
        localpart: contact.username,
        domainpart: Config.get(:domain_name),
        resourcepart: :_
      }

      case JidConnRegistry.match_one(pattern) do
        {jid, conn} -> {jid, conn}
        nil -> {nil, nil}
      end
    end)
    |> Enum.reject(&match?({nil, nil}, &1))
    |> Enum.map(fn {contact, conn} ->
      attrs = %{
        from: Jid.full_jid(state.client.jid),
        to: Jid.bare_jid(contact)
      }

      resp =
        presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)

      {conn, resp}
    end)
  end

  defp create_presence_probe(users, state) do
    users
    |> Enum.map(fn contact ->
      pattern = %Jid{
        localpart: contact.username,
        domainpart: Config.get(:domain_name),
        resourcepart: :_
      }

      case JidConnRegistry.match_one(pattern) do
        {jid, conn} -> {jid, conn}
        nil -> {nil, nil}
      end
    end)
    |> Enum.reject(&match?({nil, nil}, &1))
    |> Enum.map(fn {contact, _conn} ->
      attrs = %{
        from: Jid.full_jid(contact),
        to: Jid.bare_jid(state.client.jid)
      }

      resp =
        presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)

      {state.to, resp}
    end)
  end

  def presence_template(%{from: from, to: to}, content) do
    {:presence, [from: from, to: to], content}
  end
end
