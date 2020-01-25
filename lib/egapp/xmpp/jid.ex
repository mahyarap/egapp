defmodule Egapp.XMPP.Jid do
  defstruct [:localpart, :domainpart, :resourcepart]

  def bare_jid(jid) do
    jid.localpart <> "@" <> jid.domainpart
  end

  def full_jid(jid) do
    bare_jid(jid) <> "/" <> jid.resourcepart
  end
end
