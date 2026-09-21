# Visual engineering checks

All images below are actual model outputs with generic prompts. These examples do not establish general quality equivalence. Full settings and limitations: [performance](../performance.md) and [small Macs](../small-macs.md).

## INT8 Fast mode

| Case | Normal | Fast |
|---|---|---|
| text | ![text normal](../media/performance/cache-suite-int8_convrot-text-normal.png) | ![text fast](../media/performance/cache-suite-int8_convrot-text-fast.png) |
| portrait | ![portrait normal](../media/performance/cache-suite-int8_convrot-portrait-normal.png) | ![portrait fast](../media/performance/cache-suite-int8_convrot-portrait-fast.png) |
| rgba | ![rgba normal](../media/performance/cache-suite-int8_convrot-rgba-normal.png) | ![rgba fast](../media/performance/cache-suite-int8_convrot-rgba-fast.png) |
| edit | ![edit normal](../media/performance/cache-suite-int8_convrot-edit-normal.png) | ![edit fast](../media/performance/cache-suite-int8_convrot-edit-fast.png) |

## Sequential q4 RGB probe

Not the production app backend. Both 512² and 1024² cup probes completed below a 6 GiB process budget on an M3 Ultra with 512 GiB RAM. Small-Mac hardware is not emulated.

![mlx-q4-sequential-1024-20-budget6](../media/performance/mlx-q4-sequential-1024-20-budget6.png)

![mlx-q4-sequential-text-512-40-budget6](../media/performance/mlx-q4-sequential-text-512-40-budget6.png)

![mlx-q4-sequential-portrait-512-40-budget6](../media/performance/mlx-q4-sequential-portrait-512-40-budget6.png)
