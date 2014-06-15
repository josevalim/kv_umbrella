defmodule KV.RegistryTest do
  use ExUnit.Case, async: true

  defmodule Forwarder do
    use GenEvent

    def handle_event(event, parent) do
      send parent, event
      {:ok, parent}
    end
  end

  setup do
    ets = :ets.new(:registry_table, [:set, :public])
    registry = start_registry(ets)
    {:ok, registry: registry, ets: ets}
  end

  defp start_registry(ets) do
    {:ok, sup} = KV.Bucket.Supervisor.start_link
    {:ok, manager} = GenEvent.start_link
    {:ok, registry} = KV.Registry.start_link(ets, manager, sup)
    GenEvent.add_handler(manager, Forwarder, self(), link: true)
    registry
  end

  test "sends events on create and crash", %{registry: registry, ets: ets} do
    KV.Registry.create(registry, "shopping")
    {:ok, bucket} = KV.Registry.lookup(ets, "shopping")
    assert_receive {:create, "shopping", ^bucket}

    Agent.stop(bucket)
    assert_receive {:exit, "shopping", ^bucket}
  end

  test "spawns buckets", %{registry: registry, ets: ets} do
    assert KV.Registry.lookup(ets, "shopping") == :error

    KV.Registry.create(registry, "shopping")
    assert {:ok, bucket} = KV.Registry.lookup(ets, "shopping")

    KV.Bucket.put(bucket, "milk", 1)
    assert KV.Bucket.get(bucket, "milk") == 1
  end

  test "removes buckets on exit", %{registry: registry, ets: ets} do
    KV.Registry.create(registry, "shopping")
    {:ok, bucket} = KV.Registry.lookup(ets, "shopping")
    Agent.stop(bucket)
    assert_receive {:exit, "shopping", ^bucket} # Wait for event
    assert KV.Registry.lookup(ets, "shopping") == :error
  end

  test "removes bucket on crash", %{registry: registry, ets: ets} do
    KV.Registry.create(registry, "shopping")
    {:ok, bucket} = KV.Registry.lookup(ets, "shopping")

    # Kill the bucket and wait for the notification
    Process.exit(bucket, :shutdown)
    assert_receive {:exit, "shopping", ^bucket}
    assert KV.Registry.lookup(ets, "shopping") == :error
  end

  test "monitors existing entries", %{registry: registry, ets: ets} do
    bucket = KV.Registry.create(registry, "shopping")

    # Kill the registry. We unlink first, otherwise it will kill the test
    Process.unlink(registry)
    Process.exit(registry, :shutdown)

    # Start a new registry with the existing table and access the bucket
    start_registry(ets)
    assert KV.Registry.lookup(ets, "shopping") == {:ok, bucket}

    # Once the bucket dies, we should receive notifications
    Process.exit(bucket, :shutdown)
    assert_receive {:exit, "shopping", ^bucket}
    assert KV.Registry.lookup(ets, "shopping") == :error
  end
end
