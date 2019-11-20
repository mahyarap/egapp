defmodule Egapp.SASL.Plain do
  @behaviour Egapp.SASL

  @impl Egapp.SASL
  def authenticate(message) do
    [xmlcdata: token] = message
    result =
      Base.decode64!(token)
      |> String.split(<<0::utf8>>)
      |> Enum.slice(1, 2)
    username = Enum.at(result, 0)
    password = Enum.at(result, 1)
    {username, password}
    Egapp.XMPP.Element.success()
  end
end
