for (const id of [CID(open_raw), CID(poll_raw), CID(close_window), CID(capture), CID(surface_raw)]) {
  if (id !== undefined) io_eff(id, () => ({ $: CID(Fail), error: io_tup(1610612737, "Vulkan windows require a native build") }));
}
