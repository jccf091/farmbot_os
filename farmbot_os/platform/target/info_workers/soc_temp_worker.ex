defmodule Farmbot.Target.SocTempWorker do
  @moduledoc false

  use GenServer
  @default_timeout_ms 60_000
  @error_timeout_ms 5_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([]) do
    {:ok, nil, 0}
  end

  def handle_info(:report_temp, state) do
    {temp_str, 0} = Nerves.Runtime.cmd("vcgencmd", ["measure_temp"], :return)

    temp =
      temp_str
      |> String.trim()
      |> String.split("=")
      |> List.last()
      |> Float.parse()
      |> elem(0)

    if GenServer.whereis(Farmbot.BotState) do
      Farmbot.BotState.report_soc_temp(temp)
      {:noreply, state, @default_timeout_ms}
    else
      {:noreply, state, @error_timeout_ms}
    end
  end
end
