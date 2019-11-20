defmodule Egapp.SASL.Digest do
  def authenticate(message) do
    Egapp.XMPP.Element.challenge()
  end
end
