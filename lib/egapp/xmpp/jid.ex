defmodule Egapp.XMPP.Jid do
  defstruct [:localpart, :domainpart, :resourcepart]

  @jid_re ~r|^(?<localpart>[^@]+)@(?<domainpart>[^/]+)(/(?<resourcepart>.*))?$|
  @partial_jid_re ~r|^((?<localpart>[^@]+)@)?(?<domainpart>[^/]+)(/(?<resourcepart>.*))?$|

  def bare_jid(jid) do
    jid.localpart <> "@" <> jid.domainpart
  end

  def full_jid(jid) do
    bare_jid(jid) <> "/" <> jid.resourcepart
  end

  def parse(str) do
    do_parse(str, @jid_re)
  end

  def partial_parse(str) do
    do_parse(str, @partial_jid_re)
  end

  defp do_parse(str, re) do
    result = Regex.named_captures(re, str)

    %__MODULE__{
      localpart: result["localpart"],
      domainpart: result["domainpart"],
      resourcepart: result["resourcepart"]
    }
  end
end
