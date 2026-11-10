// Run only inside the disposable Juice Shop container. It changes the Node
// process clock, never the Windows or Docker host clock.
const RealDate = Date
const octoberTime = RealDate.parse('2026-10-15T12:00:00.000Z')

global.Date = class OctoberDate extends RealDate {
  constructor (...args) {
    super(...(args.length === 0 ? [octoberTime] : args))
  }

  static now () {
    return octoberTime
  }
}
