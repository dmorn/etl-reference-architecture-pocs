# POC.BP
## Example session
```
iex(1)> {:ok, c} = GenStage.start_link(POC.BP.Receiver, %{measurements_path: "data.6.csv", wait_ms: 1, force: true, sync: false, id: "async"})
{:ok, #PID<0.229.0>}
iex(2)> {:ok, b} = GenStage.start_link(POC.BP.Transformer, %{wait_ms: 1, max_concurrency: 8})                                                 
{:ok, #PID<0.235.0>}
iex(3)> {:ok, a} = GenStage.start_link(POC.BP.Miner, "fake.dat")                                                                              
{:ok, #PID<0.237.0>}
iex(4)> GenStage.sync_subscribe(c, to: b, max_demand: 200, min_demand: 150)                                                                   
{:ok, #Reference<0.904175418.2289303554.190321>}
iex(5)> GenStage.sync_subscribe(b, to: a, max_demand: 200, min_demand: 150)                                                                   
{:ok, #Reference<0.904175418.2289303554.190332>}
iex(6)> 
10:09:10.192 [info]  Consumer reached :end_of_stream!
 
10:09:10.209 [info]  Preparing report with data in "data.6.csv"
 
10:09:10.289 [info]  Report is available at "data.6.csv.vl.html"
 
nil
iex(7)> 
```


