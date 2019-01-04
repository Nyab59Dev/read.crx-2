interface NotchedMouseWheelEvent extends MouseEvent {
  wheelDelta: number;
}

export default class VirtualNotch {
  private wheelDelta = 0;
  private lastMouseWheel = Date.now();

  constructor(private element: Element, private threshold = 100) {
    this.element.on("wheel", this.onMouseWheel.bind(this), { passive: true });
    setInterval(this.onInterval.bind(this), 500);
  }

  private onInterval() {
    if (this.lastMouseWheel < Date.now() - 500) {
      this.wheelDelta = 0;
    }
  }

  private onMouseWheel(e: WheelEvent) {
    // @ts-ignore: true === falseは常にfalse
    if ("&[BROWSER]" === "chrome") {
      this.wheelDelta += e.deltaY;
    // @ts-ignore: true === falseは常にfalse
    } else if ("&[BROWSER]" === "firefox") {
      this.wheelDelta += e.deltaY * 40;
    }

    this.lastMouseWheel = Date.now();

    while (Math.abs(this.wheelDelta) >= this.threshold) {
      const event = <NotchedMouseWheelEvent>new MouseEvent("notchedmousewheel");
      event.wheelDelta = this.threshold * Math.sign(this.wheelDelta);
      this.wheelDelta -= event.wheelDelta;
      this.element.emit(event);
    }
  }
}
