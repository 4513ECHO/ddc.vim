import type {
  Context,
  Item,
} from "https://deno.land/x/ddu_vim@v4.1.1/types.ts";
import { BaseSource } from "https://deno.land/x/ddu_vim@v4.1.1/base/source.ts";
import { type Denops, vars } from "https://deno.land/x/ddu_vim@v4.1.1/deps.ts";
import type { DdcItem } from "../ddc/types.ts";

type Params = Record<string, never>;

export type ActionData = {
  text: string;
  item: DdcItem;
};

export class Source extends BaseSource<Params> {
  override kind = "word";

  override gather(args: {
    denops: Denops;
    context: Context;
    sourceParams: Params;
  }): ReadableStream<Item<ActionData>[]> {
    return new ReadableStream({
      async start(controller) {
        const ddcItems = await vars.g.get(
          args.denops,
          "ddc#_items",
          [],
        ) as DdcItem[];

        const items: Item<ActionData>[] = ddcItems
          .map((item) => ({
            word: item.word,
            display: item.abbr,
            action: {
              text: item.word,
              item,
            },
          }));

        controller.enqueue(items);
        controller.close();
      },
    });
  }

  override params(): Params {
    return {};
  }
}
