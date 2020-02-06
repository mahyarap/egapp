defmodule Egapp.XMPP.Stanza do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Element
  alias Egapp.JidConnRegistry

  def iq(%{"type" => "get"} = attrs, {"query", child_attrs, child_data}, state) do
    content = Element.query(child_attrs, child_data, state)

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"vCard", child_attrs, child_data}, state) do
    content = Element.vcard(child_attrs, child_data, state)

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"time", child_attrs, child_data}, state) do
    content = Element.time(child_attrs, child_data, state)

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"ping", child_attrs, child_data}, state) do
    content = Element.ping(child_attrs, child_data, state)

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(
        %{"type" => "set"} = attrs,
        {"bind", %{"xmlns" => Const.xmlns_bind()} = child_attrs, child_data},
        state
      ) do
    content = Element.bind(child_attrs, child_data, state)

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"session", _child_attrs, _child_data}, state) do
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), [])
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => _type} = attrs, _data, state) do
    resp = Egapp.XMPP.Stream.error(:invalid_xml, attrs, state)
    {:error, resp}
  end

  defp iq_template(%{id: id, type: type, from: from}, content) do
    iq_attrs = [
      id: id,
      type: type
    ]

    attrs = if from, do: [{:from, from} | iq_attrs], else: iq_attrs
    content = if content, do: [content], else: []

    {:iq, attrs, content}
  end

  defp build_iq_attrs(attrs, type, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "from") || "egapp.im",
      type: type
    }
  end

  def message(%{"type" => "chat", "to" => to} = attrs, children, state) do
    to_conn =
      to
      |> Jid.parse()
      |> Jid.bare_jid()
      |> JidConnRegistry.get()

    attrs = Map.put(attrs, "from", Jid.full_jid(state.client.jid))

    content =
      children
      |> Enum.map(fn {tag_name, attrs, data} ->
        do_message(tag_name, attrs, data)
      end)

    resp =
      message_template(build_message_attrs(attrs, state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, {to_conn, resp}}
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

  defp build_message_attrs(attrs, _state) do
    %{
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "from"),
      to: Map.get(attrs, "to"),
      type: Map.get(attrs, "type")
    }
  end

  defp message_template(%{id: id, to: to, from: from, type: type}, data) do
    iq_attrs = [
      id: id,
      from: from,
      to: to,
      type: type
    ]

    {:message, iq_attrs, data}
  end

  @doc """
  Initial presence without `to`.
  """
  def presence(attrs, _child, state) when not is_map_key(attrs, "to") do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    roster.users
    |> Enum.map(fn contact ->
      {contact, JidConnRegistry.get(contact.username <> "@egapp.im")}
    end)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(fn {contact, conn} ->
      attrs = %{
        from: Jid.full_jid(state.client.jid),
        to: contact.username <> "@egapp.im"
      }

      resp =
        presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)

      {conn, resp}
    end)
  end

  defp presence_template(%{from: from, to: to}, content) do
    {:presence, [from: from, to: to], content}
  end
end
