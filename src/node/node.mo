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
        let created_at = Nat64.toText(nip.created_at);
        let _sk = "event:" # created_at # ":" # nip.id;
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
            sk = _sk;
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

  private func _fetchEvents(skLowerBound : Text, skUpperBound : Text, limit:Nat) : {
        events : [EventType];
        sk : ?Text;
    } {
        var events : Buffer.Buffer<EventType> = Buffer.fromArray([]);
        let result = CanDB.scan(
            db,
            {
                skLowerBound = "event:" # skLowerBound;
                skUpperBound = "event:" # skUpperBound;
                limit = limit;
                ascending = ?false;
            },
        );

        for (obj in result.entities.vals()) {
            let event = _unwrapEvent(obj);
            switch (event) {
                case (?event) {
                  events.add(event)
                };
                case (null) {

                };
            };
        };
        {
            events = Buffer.toArray(events);
            sk = result.nextKey;
        };
    };

    private func _unwrapEvent(entity: Entity.Entity): ?EventType {
        let { sk; attributes } = entity;
        let id = Entity.getAttributeMapValueForKey(attributes, "id");
        let pubkey = Entity.getAttributeMapValueForKey(attributes, "pubkey");
        let created_at = Entity.getAttributeMapValueForKey(attributes, "created_at");
        let kind = Entity.getAttributeMapValueForKey(attributes, "kind");
        let tags = Entity.getAttributeMapValueForKey(attributes, "tags");
        let content = Entity.getAttributeMapValueForKey(attributes, "content");
        let sig = Entity.getAttributeMapValueForKey(attributes, "sig");

        switch(id, pubkey, created_at, kind, tags, content, sig) {
            case (
                ?(#text(id)),
                ?(#text(pubkey)),
                ?(#int(created_at)),
                ?(#int(kind)),
                ?(#tree(tags)),
                ?(#text(content)),
                ?(#text(sig)),
            ) 
            { 
                 let result = {
                    id = id;
                    pubkey = pubkey;
                    created_at = Nat64.fromIntWrap(created_at);
                    kind = Nat64.fromIntWrap(kind);
                    tags = [];
                    content = content;
                    sig = sig;
                 };
                 ?#NIPS01(result)
            };
            case _ { 
                null 
            }
        };
    };
};
