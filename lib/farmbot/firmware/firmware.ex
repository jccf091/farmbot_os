defmodule Farmbot.Firmware do
  @moduledoc "Allows communication with the firmware."

  use GenStage
  require Logger

  @handler Application.get_env(:farmbot, :behaviour)[:firmware_handler] || raise("No fw handler.")

  defdelegate move_absolute(vec3), to: @handler
  defdelegate calibrate(axis), to: @handler
  defdelegate update_param(param, val), to: @handler
  defdelegate read_param(param), to: @handler
  defdelegate emergency_lock(), to: @handler
  defdelegate emergency_unlock(), to: @handler
  defdelegate find_home(axis), to: @handler
  defdelegate read_pin(pin, mode), to: @handler
  defdelegate write_pin(pin, mode, value), to: @handler

  @doc "Start the firmware services."
  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  ## GenStage

  defmodule State do
    defstruct idle: false
  end

  def init([]) do
    {:producer_consumer, %State{}, subscribe_to: [@handler], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_events(gcodes, _from, state) do
    {diffs, state} = handle_gcodes(gcodes, state)
    {:noreply, diffs, state}
  end

  defp handle_gcodes(codes, state, acc \\ [])

  defp handle_gcodes([], state, acc), do: {Enum.reverse(acc), state}

  defp handle_gcodes([code | rest], state, acc) do
    case handle_gcode(code, state) do
      {nil, state} -> handle_gcodes(rest, state, acc)
      {key, diff, state} -> handle_gcodes(rest, state, [{key, diff} | acc])
    end
  end

  defp handle_gcode({:debug_message, _message}, state) do
    {nil, state}
  end

  defp handle_gcode({:report_current_position, x, y, z}, state) do
    {:location_data, %{position: %{x: round(x), y: round(y), z: round(z)}}, state}
  end

  defp handle_gcode({:report_encoder_position_scaled, x, y, z}, state) do
    {:location_data, %{scaled_encoders: %{x: x, y: y, z: z}}, state}
  end

  defp handle_gcode({:report_encoder_position_raw, x, y, z}, state) do
    {:location_data, %{raw_encoders: %{x: x, y: y, z: z}}, state}
  end

  defp handle_gcode({:report_end_stops, xa, xb, ya, yb, za, zb}, state) do
    diff = %{end_stops: %{xa: xa, xb: xb, ya: ya, yb: yb, za: za, zb: zb}}
    {:location_data, diff, state}
    {nil, state}
  end

  defp handle_gcode(:idle, state) do
    {:informational_settings, %{busy: false}, %{state | idle: true}}
  end

  defp handle_gcode(code, state) do
    Logger.warn("unhandled code: #{inspect(code)}")
    {nil, state}
  end
end
