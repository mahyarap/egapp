defmodule Egapp.SASL.Digest do
  def authenticate(_message) do
    Egapp.XMPP.Element.challenge()
  end

  def validate_digest_response(digest_response) do
    decoded = decode_digest_response(digest_response)

    a1 = [
      md5([decoded["username"], ':', decoded["realm"], ':', 'bar']),
      ':',
      decoded["nonce"],
      ':',
      decoded["cnonce"]
    ]

    a2 = ['AUTHENTICATE', ':', decoded["digest-uri"]]

    p1 = md5_hex(a1)
    p2 = [decoded["nonce"], ':', decoded["nc"], ':', decoded["cnonce"], ':', decoded["qop"]]
    p3 = md5_hex(a2)

    _response_value = md5_hex([p1, ':', p2, ':', p3])

    # Check response_value == decoded["response"]

    _rspauth = md5_hex([p1, ':', p2, md5_hex(tl(a2))])
  end

  defp decode_digest_response(digest_response) do
    digest_response
    |> Base.decode64!()
    |> String.split(",")
    |> Enum.map(&String.split(&1, "=", parts: 2))
    |> Map.new(fn [k, v] -> {k, String.trim(v, ~s("))} end)
  end

  defp md5(iodata) do
    :crypto.hash(:md5, iodata)
  end

  defp md5_hex(iodata) do
    md5(iodata) |> Base.encode16(case: :lower)
  end
end
