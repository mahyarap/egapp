defmodule Egapp.XMPP.Conference.Element do
  require Egapp.Constants, as: Const

  def query(%{"xmlns" => Const.xmlns_disco_info(), "node" => Const.xmlns_muc_traffic}, _data, _state) do
    {
      :error,
      [type: 'cancel'],
      [{:"service-unavailable", [xmlns: Const.xmlns_stanza], []}]
    }
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, state) do
    content =
      state.cats
      |> Enum.filter(fn cat -> cat.address() == "conference.egapp.im" end)
      |> Enum.map(fn cat -> [cat.identity() | cat.features()] end)
      |> hd()

    Egapp.XMPP.Element.query_template([xmlns: Const.xmlns_disco_info()], content)
  end
end
