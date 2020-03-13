defmodule Egapp.XMPP.Conference.Element do
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Element

  def query(
        %{"xmlns" => Const.xmlns_disco_info(), "node" => Const.xmlns_muc_traffic()},
        _data,
        state
      ) do
    resp = {
      :error,
      [type: 'cancel'],
      [{:"service-unavailable", [xmlns: Const.xmlns_stanza()], []}]
    }

    {state.to, resp}
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, state) do
    content =
      state.cats
      |> Enum.filter(fn cat -> cat.address() == "conference.egapp.im" end)
      |> Enum.map(fn cat -> [cat.identity() | cat.features()] end)
      |> hd()

    resp = Element.query_template([xmlns: Const.xmlns_disco_info()], content)
    {:ok, [{state.to, resp}]}
  end
end
