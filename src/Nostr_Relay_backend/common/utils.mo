import JSON "mo:serde/JSON";
import Candid "mo:serde/Candid";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Bool "mo:base/Bool";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import NIP01 "../models/NIPS01";
import Filter "../models/Filter";
import EventType "../models/EventType";
import Database "database";
import Sha256 "mo:sha2/Sha256";

//["REQ", <subscription_id>, <filters JSON>...]
module {

    private type NIP01 = NIP01.NIP01;
    private type EventType = EventType.EventType;
    public type Event = {
        kind : Nat64;
    };
    public func handleMessage(json : Text) : async Text {
        try {
            let message = await* _parseMessage(json);
            switch (message[0]) {
                case ("REQ") await _handleReq(message[1], message[2]);
                case ("EVENT") await _handleEvent(message[1]);
                case ("CLOSE") await _handleClose(message[1]);
                case (_) _noticeToJSON("Bad Request");
            };
        } catch (e) {
            _noticeToJSON("Error Parsing message: " #json);
        };
    };

    public func _handleReq(subscriptionId : Text, json : Text) : async Text {
        try {
            let filter = await* Filter.fromJSON(json);
            // query database and send back json data matching filter
            "";
        } catch (e) {
            _noticeToJSON(Error.message(e));
        };
    };

    public func _handleEvent(json : Text) : async Text {
        let kind = await* _parseKind(json);
        let created_at = Nat64.fromIntWrap(Time.now());
        let hash = Sha256.fromBlob(#sha256,Text.encodeUtf8(json));
        let eventId = Nat32.toText(Blob.hash(hash));
        try {
            await Database.putEvent(kind,json,created_at,eventId);
            await* _okToJSON(eventId, true, "")
        } catch (e) {
            await* _okToJSON(eventId, false, Error.message(e))
        };
    };

    public func _handleClose(subscriptionId : Text) : async Text {
        try {
            ""
        } catch (e) {
            ""
        };
    };

    public func _parseMessage(json : Text) : async* [Text] {
        let result = JSON.fromText(json, null);
        switch (result) {
            case (#ok(blob)) {
                let message : ?[Text] = from_candid (blob);
                switch (message) {
                    case (?message) message;
                    case (_) throw (Error.reject("Error Parsing JSON"));
                };
            };
            case (#err(value)) throw (Error.reject(value));
        };
    };

    public func _parseKind(json : Text): async* Nat64 {
        let result = JSON.fromText(json, null);
        switch (result) {
            case (#ok(blob)) {
                let event : ?Event = from_candid (blob);
                switch (event) {
                    case (?event) event.kind;
                    case (_) throw (Error.reject("Error Parsing JSON: "#json));
                };
            };
            case (#err(value)) throw (Error.reject(value));
        };
        //["EVENT", <event JSON as defined above>]
    };

    public func _parseClose() {
        //["CLOSE", <subscription_id>]
    };

    public func _parseTagValue() {
        //"#<single-letter (a-zA-Z)>": <a list of tag values, for #e — a list of event ids, for #p — a list of event pubkeys etc>,
    };

    //relay to client
    public func _eventToJSON(eventType : EventType, subscriptionId : Text) : async* Text {
        let messageBuffer : Buffer.Buffer<Text> = Buffer.fromArray(["EVENT", subscriptionId]);
        switch (eventType) {
            case (#NIPS01(nip)) {
                let json = await* NIP01.toJSON(nip);
                messageBuffer.add(json);
            };
        };
        let blob = to_candid (Buffer.toArray(messageBuffer));
        let field_keys = [];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) throw (Error.reject(value));
        };
        //["EVENT", <subscription_id>, <event JSON as defined above>]
    };

    public func _okToJSON(eventId : Text, success : Bool, message : Text) : async* Text {
        let blob = to_candid (["OK", eventId, Bool.toText(success), message]);
        let field_keys = [];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) throw (Error.reject(value));
        };
        //["OK", <event_id>, <true|false>, <message>]
    };

    public func _eoseToJSON(subscriptionId : Text) : async* Text {
        let blob = to_candid (["EOSE", subscriptionId]);
        let field_keys = [];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) throw (Error.reject(value));
        };
        //["EOSE", <subscription_id>]
    };

    public func _noticeToJSON(message : Text) : Text {
        let blob = to_candid (["NOTICE", message]);
        let field_keys = [];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) "[\"NOTICE\",\"BadRequest\"]";
        };
        //["NOTICE", <message>]
    };

};
