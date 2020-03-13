defmodule Egapp.XMPP.Server.Stanza do
  require Ecto.Query
  require Egapp.Constants, as: Const

  import Egapp.XMPP.Stanza,
    only: [
      iq_template: 2,
      build_iq_attrs: 3,
      message_template: 2,
      presence_template: 2,
      build_message_attrs: 2
    ]

  alias Egapp.Config
  alias Egapp.XMPP.Jid
  alias Egapp.JidConnRegistry
  alias Egapp.XMPP.Server.Element

  def iq(%{"type" => "get"} = attrs, {"query", child_attrs, child_data}, state) do
    {status, result} = Element.query(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"vCard", child_attrs, child_data}, state) do
    {status, result} = Element.vcard(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"time", child_attrs, child_data}, state) do
    {status, result} = Element.time(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"ping", child_attrs, child_data}, state) do
    {status, result} = Element.ping(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"query", child_attrs, child_data}, state) do
    child_data =
      case child_data do
        [{:xmlel, tag_name, child_attrs, child_data}] ->
          {tag_name, to_map(child_attrs), child_data}
      end

    {status, result} = Element.query(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"bind", child_attrs, child_data}, state) do
    {status, result} = Element.bind(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"session", child_attrs, child_data}, state) do
    {status, result} = Element.session(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(attrs, {element, _child_attrs, _child_data}, state) do
    resp =
      [{state.to, Egapp.XMPP.Element.bad_request_error(:modify, "unknown element: #{element}")}]
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, :error, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def message(%{"to" => to} = attrs, children, state) do
    {_, conn} =
      to
      |> Jid.parse()
      |> Jid.bare_jid()
      |> JidConnRegistry.match()
      # TODO: fix this
      |> hd()

    attrs = Map.put(attrs, "from", Jid.full_jid(state.client.jid))

    content =
      children
      |> Enum.map(fn {tag_name, attrs, data} ->
        do_message(tag_name, attrs, data)
      end)

    resp =
      message_template(build_message_attrs(attrs, state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, {conn, resp}}
  end

  defp do_message("active", _attrs, _data) do
    {:active, [xmlns: Const.xmlns_chatstates()], []}
  end

  defp do_message("composing", _attrs, _data) do
    {:composing, [xmlns: Const.xmlns_chatstates()], []}
  end

  defp do_message("paused", _attrs, _data) do
    {:paused, [xmlns: Const.xmlns_chatstates()], []}
  end

  defp do_message("body", _attrs, data) do
    [xmlcdata: body] = data
    {:body, [String.to_charlist(body)]}
  end

  def presence(attrs, _data, state) when is_map_key(attrs, "to") do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    roster.users
    |> Enum.map(fn contact ->
      jid = %Jid{
        localpart: contact.username,
        domainpart: Config.get(:domain_name)
      }

      {contact, JidConnRegistry.match(Jid.bare_jid(jid))}
    end)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(fn {contact, conn} ->
      attrs = %{
        from: Jid.full_jid(state.client.jid),
        to: contact.username <> "@egapp.im"
      }

      resp =
        Egapp.XMPP.Stanza.presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)

      {conn, resp}
    end)
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
      jid = %Jid{
        localpart: contact.username,
        domainpart: Config.get(:domain_name)
      }

      Jid.bare_jid(jid)
      |> JidConnRegistry.match()
    end)
    |> List.flatten()
    |> Enum.map(fn {jid, conn} ->
      attrs = %{
        from: Jid.full_jid(state.client.jid),
        to: Jid.bare_jid(jid)
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
      jid = %Jid{
        localpart: contact.username,
        domainpart: Config.get(:domain_name)
      }

      Jid.bare_jid(jid)
      |> JidConnRegistry.match()
    end)
    |> List.flatten()
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

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
