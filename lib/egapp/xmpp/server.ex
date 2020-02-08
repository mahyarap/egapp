defmodule Egapp.XMPP.Server do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Element
  alias Egapp.JidConnRegistry

  def address do
    "egapp.im"
  end

  def identity do
    Element.identity('server', 'im')
  end

  def features do
    [
      Element.feature(Const.xmlns_disco_info()),
      Element.feature(Const.xmlns_disco_items()),
      Element.feature(Const.xmlns_ping()),
      Element.feature(Const.xmlns_vcard()),
      Element.feature(Const.xmlns_version()),
      Element.feature(Const.xmlns_last())
    ]
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
