import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Buffer "mo:stablebuffer/StableBuffer";

import Admin "mo:candb/CanDBAdmin";
import CA "mo:candb/CanisterActions";
import CanisterMap "mo:candb/CanisterMap";
import NodeCanister "../node/node";
import Utils "../Utils";

shared ({caller = owner}) actor class IndexCanister() = this {
  stable var pkToCanisterMap = CanisterMap.init();

  /// @required API (Do not delete or change)
  ///
  /// Get all canisters for an specific PK
  ///
  /// This method is called often by the candb-client query & update methods. 
  public shared query({caller = caller}) func getCanistersByPK(pk: Text): async [Text] {
    getCanisterIdsIfExists(pk);
  };
  
  /// Helper function that creates a node canister for a given PK
  func createNodeCanister(pk: Text, controllers: ?[Principal]): async Text {
    Debug.print("creating new node canister with pk=" # pk);
    Cycles.add(300_000_000_000);
    let newNodeCanister = await NodeCanister.NodeCanister({
      partitionKey = pk;
      scalingOptions = {
        autoScalingHook = autoScaleNodeCanister;
        sizeLimit = #heapSize(900_000_000);
      };
      owners = ?[owner, Principal.fromActor(this)];
    });
    let newNodeCanisterPrincipal = Principal.fromActor(newNodeCanister);
    await CA.updateCanisterSettings({
      canisterId = newNodeCanisterPrincipal;
      settings = {
        controllers = controllers;
        compute_allocation = ?0;
        memory_allocation = ?0;
        freezing_threshold = ?2592000;
      }
    });

    let newNodeCanisterId = Principal.toText(newNodeCanisterPrincipal);
    pkToCanisterMap := CanisterMap.add(pkToCanisterMap, pk, newNodeCanisterId);

    newNodeCanisterId;
  };

  /// This hook is called by CanDB for AutoScaling the Node Service Actor.
  ///
  /// If the developer does not spin up an additional Node canister in the same partition within this method, auto-scaling will NOT work
  public shared ({caller = caller}) func autoScaleNodeCanister(pk: Text): async Text {
    // Auto-Scaling Authorization - ensure the request to auto-scale the partition is coming from an existing canister in the partition, otherwise reject it
    if (Utils.callingCanisterOwnsPK(caller, pkToCanisterMap, pk)) {
      await createNodeCanister(pk, ?[owner, Principal.fromActor(this)]);
    } else {
      Debug.trap("error, called by non-controller=" # debug_show(caller));
    };
  };
  
  /// Public API endpoint for spinning up a canister from the Node Actor
  public shared({caller = creator}) func createNode(): async ?Text {
    let callerPrincipalId = Principal.toText(creator);
    let nodePK = "node#" # callerPrincipalId;
    let canisterIds = getCanisterIdsIfExists(nodePK);
    // does not exist
    if (canisterIds == []) {
      ?(await createNodeCanister(nodePK, ?[owner, Principal.fromActor(this)]));
    // already exists
    } else {
      Debug.print("already exists, not creating and returning null");
      null 
    };
  };

  /// Spins down all canisters belonging to a specific node (transfers cycles back to the index canister, and stops/deletes all canisters)
  public shared({caller = caller}) func deleteLoggedInNode(): async () {
    let callerPrincipalId = Principal.toText(caller);
    let nodePK = "node#" # callerPrincipalId;
    let canisterIds = getCanisterIdsIfExists(nodePK);
    if (canisterIds == []) {
      Debug.print("canister for node with principal=" # callerPrincipalId # " pk=" # nodePK # " does not exist");
    } else {
      // can choose to use this statusMap for to detect failures and prompt retries if desired 
      let statusMap = await Admin.transferCyclesStopAndDeleteCanisters(canisterIds);
      pkToCanisterMap := CanisterMap.delete(pkToCanisterMap, nodePK);
    };
  };

  /// @required function (Do not delete or change)
  ///
  /// Helper method acting as an interface for returning an empty array if no canisters
  /// exist for the given PK
  func getCanisterIdsIfExists(pk: Text): [Text] {
    switch(CanisterMap.get(pkToCanisterMap, pk)) {
      case null { [] };
      case (?canisterIdsBuffer) { Buffer.toArray(canisterIdsBuffer) } 
    }
  };

  /// Upgrade node canisters in a PK range, i.e. rolling upgrades (limit is fixed at upgrading the canisters of 5 PKs per call)
  public shared({ caller = caller }) func upgradeNodeCanistersInPKRange(wasmModule: Blob): async Admin.UpgradePKRangeResult {
    if (caller != owner) { // basic authorization
      return {
        upgradeCanisterResults = [];
        nextKey = null;
      }
    }; 

    await Admin.upgradeCanistersInPKRange({
      canisterMap = pkToCanisterMap;
      lowerPK = "node#";
      upperPK = "node#:";
      limit = 5;
      wasmModule = wasmModule;
      scalingOptions = {
        autoScalingHook = autoScaleNodeCanister;
        sizeLimit = #count(20)
      };
      owners = ?[owner, Principal.fromActor(this)];
    });
  };
}