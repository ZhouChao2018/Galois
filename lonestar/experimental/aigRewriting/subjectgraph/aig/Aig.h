/*
 * This file belongs to the Galois project, a C++ library for exploiting parallelism.
 * The code is being released under the terms of the 3-Clause BSD License (a
 * copy is located in LICENSE.txt at the top-level directory).
 *
 * Copyright (C) 2018, The University of Texas at Austin. All rights reserved.
 * UNIVERSITY EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES CONCERNING THIS
 * SOFTWARE AND DOCUMENTATION, INCLUDING ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR ANY PARTICULAR PURPOSE, NON-INFRINGEMENT AND WARRANTIES OF
 * PERFORMANCE, AND ANY WARRANTY THAT MIGHT OTHERWISE ARISE FROM COURSE OF
 * DEALING OR USAGE OF TRADE.  NO WARRANTY IS EITHER EXPRESS OR IMPLIED WITH
 * RESPECT TO THE USE OF THE SOFTWARE OR DOCUMENTATION. Under no circumstances
 * shall University be liable for incidental, special, indirect, direct or
 * consequential damages or loss of profits, interruption of business, or
 * related expenses which may arise from use of Software or Documentation,
 * including but not limited to those resulting from defects in Software and/or
 * Documentation, or loss or inaccuracy of data of any kind.
 */

#ifndef AIG_AIG_H_
#define AIG_AIG_H_

#include "galois/Galois.h"
#include "galois/runtime/Statistics.h"
#include "galois/graphs/First_SepInOut_Graph.h"

#include <iostream>
#include <vector>
#include <stack>
#include <set>
#include <utility>
#include <unordered_map>

namespace andInverterGraph {

struct NodeData;

// Nodes hold a NodeData structure, edges hold a boolean value and are
// directional with InOut distinction
typedef galois::graphs::First_SepInOut_Graph<NodeData, bool, true, true> Graph;

typedef Graph::GraphNode GNode;

enum NodeType { AND, PI, PO, LATCH, CONSTZERO, CHOICE };

struct NodeData {
  int id;
  int level;
  int nFanout;
  short int counter;
  NodeType type;

  NodeData() : level(0), nFanout(0), counter(0) {}
};

class Aig {

private:
  Graph graph;
  std::string designName;
  std::vector<GNode> nodes;
  std::vector<GNode> inputNodes;
  std::vector<GNode> latchNodes;
  std::vector<GNode> outputNodes;
  std::vector<std::string> inputNames;
  std::vector<std::string> latchNames;
  std::vector<std::string> outputNames;
  std::vector<std::pair<int, int>> nodesTravId;
  std::vector<std::unordered_multimap<unsigned, GNode>> nodesFanoutMap;

  void topologicalSortAll(GNode node, std::vector<bool>& visited,
                          std::stack<GNode>& stack);
  void topologicalSortAnds(GNode node, std::vector<bool>& visited,
                           std::stack<GNode>& stack);

public:
  Aig();
  virtual ~Aig();

  Graph& getGraph();
  std::vector<GNode>& getNodes();
  std::vector<GNode>& getInputNodes();
  std::vector<GNode>& getLatchNodes();
  std::vector<GNode>& getOutputNodes();
  std::vector<std::string>& getInputNames();
  void setInputNames(std::vector<std::string> inputNames);
  std::vector<std::string>& getLatchNames();
  void setLatchNames(std::vector<std::string> latchNames);
  std::vector<std::string>& getOutputNames();
  void setOutputNames(std::vector<std::string> outputNames);
  std::vector<std::pair<int, int>>& getNodesTravId();
  void registerTravId(int nodeId, int threadId, int travId);
  bool lookupTravId(int nodeId, int threadId, int travId);
  std::unordered_multimap<unsigned, GNode>& getFanoutMap(int nodeId);
  std::vector<std::unordered_multimap<unsigned, GNode>>& getNodesFanoutMap();
  GNode getConstZero();
  int getNumInputs();
  int getNumLatches();
  int getNumOutputs();
  int getNumAnds();
  int getDepth();

  std::string getDesignName();
  void setDesignName(std::string designName);

  void insertNodeInFanoutMap(GNode andNode, GNode lhsNode, GNode rhsNode,
                             bool lhsPol, bool rhsPol);
  void removeNodeInFanoutMap(GNode removedNode, GNode lhsNode, GNode rhsNode,
                             bool lhsPol, bool rhsPol);
  GNode lookupNodeInFanoutMap(GNode lhsNode, GNode rhsNode, bool lhsPol,
                              bool rhsPol);
  unsigned makeAndHashKey(GNode lhsNode, GNode rhsNode, int lhsId, int rhsId,
                          bool lhsPol, bool rhsPol);

  void resetAndIds();
  void resetAndPIsIds();
  void resetAndPOsIds();
  void resetAllIds();

  void resetAllNodeCounters();

  void computeTopologicalSortForAll(std::stack<GNode>& stack);
  void computeTopologicalSortForAnds(std::stack<GNode>& stack);

  void writeDot(std::string path, std::string dotText);
  std::string toDot();
};

} // namespace andInverterGraph

namespace aig = andInverterGraph;

#endif /* AIG_H_ */
