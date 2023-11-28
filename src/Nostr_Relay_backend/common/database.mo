import NIP01 "../models/NIPS01";
import EventType "../models/EventType";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Constants "../../Constants";
import IndexCanister "../services/IndexCanister";
import NodeCanister "../services/NodeCanister";

module {

    private type EventType = EventType.EventType;

    public composite query func fetchEvents(skLowerBound : Text, skUpperBound : Text, limit : Nat) : async {
        events : [EventType];
        sk : ?Text;
    } {
        let canister = await _getCanister(skLowerBound);
        await NodeCanister.service(canister).fetchEvents(skLowerBound, skUpperBound, limit);
    };

    public func putEvent(kind : Nat64, json : Text, created_at : Nat64, id : Text) : async () {
        let canisters = await _fetchCanisters("node#i47jd-kewyq-vcner-l4xf7-edf77-aw4xp-u2kpb-2qai2-6ie7k-tcngl-oqe");
        let size = canisters.size();
        if (size > 0) {
            let node = canisters[size -1];
            switch (kind) {
                case (1) {
                    let nip01 = await* NIP01.fromJSON(json);
                    let obj = {
                        id = id;
                        pubkey = nip01.pubkey;
                        created_at = created_at;
                        kind = kind;
                        tags = nip01.tags;
                        content = nip01.content;
                        sig = nip01.sig;
                    };
                    ignore await NodeCanister.service(node).addEntity(#NIPS01(obj))
                    //put obj into database
                };
                case (_) throw (Error.reject("Kind Not Supported: " #Nat64.toText(kind)));
            };
        };
    };

    private composite query func _getCanister(sk : Text) : async Text {
        let canisters = await IndexCanister.service(Constants.INDEX_CANISTER).getCanistersByPK(sk);
        var node = "";
        for (canister in canisters.vals()) {
            let skExists = await NodeCanister.service(canister).skExists(sk);
            if (skExists) {
                node := canister;
            };
        };
        node;
    };

    private func _fetchCanisters(pk : Text) : async [Text] {
        await IndexCanister.service(Constants.INDEX_CANISTER).getCanistersByPK(pk);
    };
};
