import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";

import CA "mo:candb/CanisterActions";
import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import EventType "../Nostr_Relay_backend/models/EventType";

shared ({ caller = owner }) actor class Node({
  partitionKey : Text;
  scalingOptions : CanDB.ScalingOptions;
  owners : ?[Principal];
}) {

  type EventType = EventType.EventType;

  /// @required (may wrap, but must be present in some form in the canister)
  ///
  /// Initialize CanDB
  stable let db = CanDB.init({
    pk = partitionKey;
    scalingOptions = scalingOptions;
    btreeOrder = null;
  });

  /// @recommended (not required) public API
  public query func getPK() : async Text { db.pk };

  /// @required public API (Do not delete or change)
  public query func skExists(sk : Text) : async Bool {
    CanDB.skExists(db, sk);
  };

  /// @required public API (Do not delete or change)
  public shared ({ caller = caller }) func transferCycles() : async () {
    if (caller == owner) {
      await CA.transferCycles(caller);
    };
  };

  /// Example of inserting a static entity into CanDB with an sk provided as a parameter
  public func addEntity(sk : Text, eventType : EventType) : async Text {
    switch (eventType) {
      case (#NIPS01(nip)) {
        let temp : Buffer.Buffer<(Text, Entity.AttributeValueRBTreeValue)> = Buffer.fromArray([]);
        for (tag in nip.tags.vals()) {
          if (tag.size() > 0) {
            if (tag.size() > 2) {
              temp.add((tag[0],#arrayText([tag[1],tag[2]])));
            } else {
              temp.add((tag[0],#arrayText([tag[1]])));
            };
          };
        };
        let map = Entity.createAttributeValueRBTreeFromKVPairs(Buffer.toArray(temp));
        await* CanDB.put(
          db,
          {
            sk = sk;
            attributes = [
              ("id", #text(nip.id)),
              ("pubkey", #text(nip.pubkey)),
              ("created_at", #int(Nat64.toNat(nip.created_at))),
              ("kind", #int(Nat64.toNat(nip.kind))),
              ("tags", #tree(map)),
              ("content", #text(nip.content)),
              ("sig", #text(nip.sig)),
            ];
          },
        );

        "pk=" # db.pk # ", sk=" # sk;
      };
    };
  };
};
