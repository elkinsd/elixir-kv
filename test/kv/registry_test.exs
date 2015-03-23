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
    {:ok, sup} = KV.Bucket.Supervisor.start_link
    {:ok, manager} = GenEvent.start_link
    {:ok, registry} = KV.Registry.start_link(:registry_table, manager, sup)

    GenEvent.add_mon_handler(manager, Forwarder, self())
    {:ok, registry: registry, ets: :registry_table}
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
    assert_receive {:exit, "shopping", ^bucket}  ## Wait for event
    assert KV.Registry.lookup(ets, "shopping") == :error
  end

  test "sends events on create and crash", %{registry: registry, ets: ets} do
    KV.Registry.create(registry, "shopping")
    {:ok, bucket} = KV.Registry.lookup(ets, "shopping")
    assert_receive {:create, "shopping", ^bucket}

    Agent.stop(bucket)
    assert_receive {:exit, "shopping", ^bucket}
  end

  test "removes buckets on crash", %{registry: registry, ets: ets} do
    KV.Registry.create(registry, "shopping")
    {:ok, bucket} = KV.Registry.lookup(ets, "shopping")

    ## Kill the bucket and wait for the notification
    Process.exit(bucket, :shutdown)
    assert_receive {:exit, "shopping", ^bucket}
    assert KV.Registry.lookup(ets, "shopping") == :error
  end
end
