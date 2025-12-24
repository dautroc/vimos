
import Foundation

print("Starting Test Runner...")
let runner = VimEngineTests()
runner.runAll()

let logicRunner = WordMotionLogicTests()
logicRunner.runAll()

let decodingRunner = ConfigDecodingTests()
decodingRunner.runAll()


