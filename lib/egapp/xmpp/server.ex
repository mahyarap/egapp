defmodule Egapp.XMPP.Server do
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Element

  def address do
    "egapp.im"
  end

  def category, do: :server

  def type, do: :im

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

  def stanza_mod do
    Egapp.XMPP.Server.Stanza
  end
end
