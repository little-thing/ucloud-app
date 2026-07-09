#!/usr/bin/env python3
"""CompShare 实例列表 + 指定实例开关机验证。"""

import json
import time

from ucloud.client import Client
from ucloud.core import exc

PUBLIC_KEY = "4eZCa5hXL3RF9WLEaD4ZdvIrT1OSoQwUJ"
PRIVATE_KEY = "AA8Z5lfwhFR1fqF9PRlssWANnFgNfVQRzBb57grVcKmK"
TARGET_ID = "uhost-1mafdpxctojn"
BASE_URL = "https://api.compshare.cn"
REGION = "cn-wlcb"


def make_client(region: str = REGION) -> Client:
    return Client(
        {
            "region": region,
            "public_key": PUBLIC_KEY,
            "private_key": PRIVATE_KEY,
            "base_url": BASE_URL,
        }
    )


def wait_state(client: Client, zone: str, uhost_id: str, targets, timeout=180):
    start = time.time()
    while time.time() - start < timeout:
        resp = client.ucompshare().invoke(
            "DescribeCompShareInstance",
            {
                "Region": REGION,
                "Zone": zone,
                "UHostIds": [uhost_id],
            },
        )
        items = resp.get("UHostSet") or []
        if not items:
            raise RuntimeError(f"实例不存在: {uhost_id}")
        state = items[0].get("State")
        print(f"  当前状态: {state}")
        if state in targets:
            return items[0]
        time.sleep(3)
    raise TimeoutError(f"等待状态超时: {targets}")


def power_cycle(client: Client, inst: dict):
    uhost_id = inst["UHostId"]
    zone = inst["Zone"]
    state = inst["State"]
    print(f"\n准备控制实例 {uhost_id} (Zone={zone}, State={state})")

    if state == "Running":
        print("执行关机 StopCompShareInstance ...")
        client.ucompshare().invoke(
            "StopCompShareInstance",
            {"Region": REGION, "Zone": zone, "UHostId": uhost_id},
        )
        wait_state(client, zone, uhost_id, {"Stopped"})
        print("关机成功，执行开机 StartCompShareInstance ...")
        client.ucompshare().invoke(
            "StartCompShareInstance",
            {"Region": REGION, "Zone": zone, "UHostId": uhost_id},
        )
        wait_state(client, zone, uhost_id, {"Running"})
        print("开机成功")
    elif state == "Stopped":
        print("执行开机 StartCompShareInstance ...")
        client.ucompshare().invoke(
            "StartCompShareInstance",
            {"Region": REGION, "Zone": zone, "UHostId": uhost_id},
        )
        wait_state(client, zone, uhost_id, {"Running"})
        print("开机成功，执行关机 StopCompShareInstance ...")
        client.ucompshare().invoke(
            "StopCompShareInstance",
            {"Region": REGION, "Zone": zone, "UHostId": uhost_id},
        )
        wait_state(client, zone, uhost_id, {"Stopped"})
        print("关机成功")
    else:
        print(f"当前状态为 {state}，先等待 Running/Stopped")
        stable = wait_state(client, zone, uhost_id, {"Running", "Stopped"})
        power_cycle(client, stable)


def main():
    client = make_client()

    print("=== 1. 拉取实例列表 (DescribeCompShareInstance) ===")
    try:
        resp = client.ucompshare().invoke(
            "DescribeCompShareInstance",
            {"Region": REGION, "Limit": 100, "Offset": 0},
        )
    except exc.UCloudException as e:
        print("列表查询失败:", e)
        raise

    total = resp.get("TotalCount", 0)
    items = resp.get("UHostSet") or []
    print(f"总数: {total}")
    for inst in items:
        brief = {
            "UHostId": inst.get("UHostId"),
            "Name": inst.get("Name"),
            "State": inst.get("State"),
            "Zone": inst.get("Zone"),
            "Region": inst.get("Region"),
            "GPU": inst.get("GPU"),
            "GpuType": inst.get("GpuType"),
        }
        print(" -", json.dumps(brief, ensure_ascii=False))

    target = next((x for x in items if x.get("UHostId") == TARGET_ID), None)
    if not target:
        print(f"\n列表未命中，按 ID 精确查询 {TARGET_ID} ...")
        resp = client.ucompshare().invoke(
            "DescribeCompShareInstance",
            {"Region": REGION, "UHostIds": [TARGET_ID]},
        )
        found = resp.get("UHostSet") or []
        if not found:
            raise SystemExit(f"未找到实例 {TARGET_ID}")
        target = found[0]

    print("\n=== 2. 控制目标实例开关机 ===")
    print(
        json.dumps(
            {
                "UHostId": target.get("UHostId"),
                "Name": target.get("Name"),
                "State": target.get("State"),
                "Zone": target.get("Zone"),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    power_cycle(client, target)
    print("\n全部完成")


if __name__ == "__main__":
    main()
