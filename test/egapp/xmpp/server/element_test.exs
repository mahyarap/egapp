defmodule Egapp.XMPP.Server.ElementTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Server.Element

  test "disco items" do
    attrs = %{"xmlns" => Const.xmlns_disco_items()}
    state = %{cats: [Egapp.XMPP.Server, Egapp.XMPP.Conference]}

    result =
      Element.query(attrs, nil, state)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()
    
    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_items()}")
    assert result =~ ~s(<item)
  end

  test "disco info for server" do
    attrs = %{"xmlns" => Const.xmlns_disco_info()}
    state = %{cats: [Egapp.XMPP.Server]}

    result =
      Element.query(attrs, nil, state)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_info()}")
    assert result =~ ~s(<identity)
    assert result =~ ~s(category="server")
    assert result =~ ~s(type="im")
    assert result =~ ~s(<feature)
  end
end
