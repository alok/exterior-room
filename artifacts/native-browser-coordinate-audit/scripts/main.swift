import Foundation
struct Fixture: Decodable { let name: String; let response: PolynomialAction }
struct Fixtures: Decodable { let cases: [Fixture] }
let path = CommandLine.arguments[1]
let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
var output: [[String:Any]] = []
for fixture in fixtures.cases {
  let action = fixture.response, p = action.point
  guard action.isValid, let mapped = action.mapDisplay([Float(-p[1]),Float(p[0]+p[2]),Float(p[2]-p[0])]) else { fatalError("invalid \(fixture.name)") }
  output.append(["name":fixture.name,"xyz":[mapped.x,mapped.y,mapped.z].map(Double.init)])
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: output,options:[.sortedKeys]))
