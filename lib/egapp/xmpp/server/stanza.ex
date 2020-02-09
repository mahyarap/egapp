defmodule Egapp.XMPP.Server.Stanza do
  require Ecto.Query

  import Egapp.XMPP.Stanza, only: [iq_template: 2, build_iq_attrs: 3]

  alias Egapp.XMPP.Jid
  alias Egapp.JidConnRegistry
  alias Egapp.XMPP.Server.Element

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

  def iq(%{"type" => "set"} = attrs, {"bind", child_attrs, child_data}, state) do
    content = Element.bind(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"session", child_attrs, child_data}, state) do
    content = Element.session(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => _type} = attrs, _data, state) do
    resp = Egapp.XMPP.Stream.error(:invalid_xml, attrs, state)
    {:error, resp}
  end

  def presence(_attrs, _data, state) do
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
        Egapp.XMPP.Stanza.presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)

      {conn, resp}
    end)
  end
end
