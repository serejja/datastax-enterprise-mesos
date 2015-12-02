package net.elodina.mesos.dse

import org.junit.Test
import org.junit.Assert._
import scala.concurrent.duration.Duration

class NodeTest {
  @Test
  def toJSON_fromJSON {
    val node: Node = new Node("1")
    var read = new Node(Util.parseJsonAsMap("" + node.toJson))
    assertNodeEquals(node, read)

    node.state = Node.State.Running
    node.runtime = new Node.Runtime("task", "slave", "executor", "host", Map("a" -> "1"))

    node.cpu = 1
    node.mem = 1024
    node.broadcast = "127.0.0.1"

    node.nodeOut = "node.out"
    node.agentOut = "agent.out"
    node.clusterName = "cluster"

    node.seed = true
    node.replaceAddress = "127.0.0.2"

    node.constraints ++= Constraint.parse("hostname=like:master")
    node.seedConstraints ++= Constraint.parse("hostname=like:master")

    node.dataFileDirs = "dataDir"
    node.commitLogDir = "logDir"
    node.savedCachesDir = "saveCachesDir"
    node.awaitConsistentStateBackoff = Duration("5 seconds")

    read = new Node(Util.parseJsonAsMap("" + node.toJson))
    assertNodeEquals(read, node)
  }

  def Runtime_toJson_fromJson {
    val runtime = new Node.Runtime("task", "slave", "executor", "host", Map("a" -> "1"))
    val read = new Node.Runtime(Util.parseJsonAsMap(runtime.toJson.toString()))
    assertRuntimeEquals(runtime, read)
  }

  def assertNodeEquals(expected: Node, actual: Node) {
    if (checkNulls(expected, actual)) return

    assertEquals(expected.id, actual.id)
    assertEquals(expected.state, actual.state)
    assertRuntimeEquals(expected.runtime, actual.runtime)

    assertEquals(expected.cpu, actual.cpu, 0.001)
    assertEquals(expected.mem, actual.mem)
    assertEquals(expected.broadcast, actual.broadcast)

    assertEquals(expected.nodeOut, actual.nodeOut)
    assertEquals(expected.agentOut, actual.agentOut)
    assertEquals(expected.clusterName, actual.clusterName)

    assertEquals(expected.seed, actual.seed)
    assertEquals(expected.replaceAddress, actual.replaceAddress)

    assertEquals(expected.constraints, actual.constraints)
    assertEquals(expected.seedConstraints, actual.seedConstraints)

    assertEquals(expected.dataFileDirs, actual.dataFileDirs)
    assertEquals(expected.commitLogDir, actual.commitLogDir)
    assertEquals(expected.savedCachesDir, actual.savedCachesDir)
    assertEquals(expected.awaitConsistentStateBackoff, actual.awaitConsistentStateBackoff)
  }

  def assertRuntimeEquals(expected: Node.Runtime, actual: Node.Runtime) {
    if (checkNulls(expected, actual)) return

    assertEquals(expected.taskId, actual.taskId)
    assertEquals(expected.slaveId, actual.slaveId)
    assertEquals(expected.executorId, actual.executorId)

    assertEquals(expected.hostname, actual.hostname)
    assertEquals(expected.attributes, actual.attributes)
  }

  private def checkNulls(expected: Object, actual: Object): Boolean = {
    if (expected == actual) return true
    if (expected == null) throw new AssertionError("actual != null")
    if (actual == null) throw new AssertionError("actual == null")
    false
  }
}
