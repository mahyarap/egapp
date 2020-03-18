defmodule Egapp.XMPP.Conference.Query do
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Element
  alias Egapp.XMPP.Conference

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

    {:ok, [{state.to, resp}]}
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, state) do
    content = [Conference.identity() | Conference.features()]
    resp = Element.query_template([xmlns: Const.xmlns_disco_info()], content)
    {:ok, [{state.to, resp}]}
  end
end
