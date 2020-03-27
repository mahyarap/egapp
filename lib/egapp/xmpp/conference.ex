defmodule Egapp.XMPP.Conference do
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Element

  def address do
    "conference.egapp.im"
  end

  def category, do: :conference

  def type, do: :text

  def identity do
    Element.identity('conference', 'text')
  end

  def features do
    [
      Element.feature(Const.xmlns_disco_info()),
      Element.feature(Const.xmlns_disco_items()),
      Element.feature(Const.xmlns_vcard()),
      Element.feature(Const.xmlns_muc())
    ]
  end

  def stanza_mod do
    Egapp.XMPP.Conference.Stanza
  end
end
