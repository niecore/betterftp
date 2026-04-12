import 'protocols/ramp_protocol.dart';
import 'protocols/twenty_min_protocol.dart';
import 'ramp_test_state.dart';
import 'test_protocol_definition.dart';

/// Maps [TestProtocol] enum values to their concrete implementations.
///
/// To add a new protocol:
/// 1. Create a class extending [TestProtocolDefinition]
/// 2. Add an entry to the [TestProtocol] enum
/// 3. Register it in [_protocols] below
class ProtocolRegistry {
  ProtocolRegistry._();

  static final Map<TestProtocol, TestProtocolDefinition> _protocols = {
    TestProtocol.ramp: RampProtocol(),
    TestProtocol.twentyMin: TwentyMinProtocol(),
  };

  /// Returns the protocol definition for the given type.
  static TestProtocolDefinition get(TestProtocol type) => _protocols[type]!;
}
