defmodule Egapp.XMPP.Jid do
  defstruct [:localpart, :domainpart, :resourcepart]

  @jid_re ~r|^(?<localpart>[^@]+)@(?<domainpart>[^/]+)(/(?<resourcepart>.*))?$|

  def bare_jid(jid) do
    jid.localpart <> "@" <> jid.domainpart
  end

  def full_jid(jid) do
    bare_jid(jid) <> "/" <> jid.resourcepart
  end

  def parse(str) do
    result = Regex.named_captures(@jid_re, str)
    %Egapp.XMPP.Jid{
      localpart: result["localpart"],
      domainpart: result["domainpart"],
      resourcepart: result["resourcepart"]
    }
  end
end
