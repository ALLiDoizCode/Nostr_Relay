import NIP01 "../models/NIPS01";
import EventType "../models/EventType";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
module {

    private type EventType = EventType.EventType;

    public func putEvent(kind : Nat64, json : Text, created_at : Nat64, id : Text) : async () {
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
                }
                //put obj into database
            };
            case (_) throw (Error.reject("Kind Not Supported: " #Nat64.toText(kind)));
        };
    };
};
