[750, 1000, 1500, 2000, 5000]
|> Enum.map(fn repeat ->
  {"hash_#{repeat}", fn ->
    POC.BP.Transformer.process_sample("this is a sentence I want to hash", repeat)
  end}
end)
|> Enum.into(%{})
|> Benchee.run()
