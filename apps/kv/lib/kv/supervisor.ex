defmodule KV.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      KV.BucketSupervisor,
      {KV.Registry, name: KV.Registry},
      {Task.Supervisor, name: KV.RouterTasks}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
