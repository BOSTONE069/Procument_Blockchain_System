import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
// Actor representing the Procurement platform backend
actor Procurement {



  // Simple event log type
  type Event = {
    timestamp: Time.Time;
    message: Text;
  };

  // Event log storage
  let eventLog = Buffer.Buffer<Event>(10);

  // Helper function to add event to log
  func logEvent(msg: Text) : () {
    eventLog.add({ timestamp = Time.now(); message = msg });
  };

  // Type representing a Tender with relevant fields
  type Tender = {
    id: Text;               // Unique identifier for the tender
    description: Text;      // Description of the tender
    issuer: Principal;      // Principal who created the tender
    createdAt: Time.Time;   // Timestamp when the tender was created
    status: TenderStatus;   // Status of the tender
  };

  // Enum for tender status
  type TenderStatus = {
    #Open;
    #Closed;
    #Awarded;
  };

  // Type representing a Bid submitted for a tender
  type Bid = {
    tenderId: Text;         // ID of the tender this bid is for
    bidder: Principal;      // Principal who submitted the bid
    amount: Nat;            // Bid amount
    submittedAt: Time.Time; // Timestamp when the bid was submitted
  };

  // Type representing an awarded tender with winning bid
  type AwardedTender = {
    id: Text;
    tender: Tender;
    winningBid: Bid;
  };

  // HashMap to store tenders with Text keys and Tender values
  let tenders = HashMap.HashMap<Text, Tender>(10, Text.equal, Text.hash);

  // HashMap to store bids with Text keys and Bid values
  let bids = HashMap.HashMap<Text, Bid>(10, Text.equal, Text.hash);

  // Create a new tender
  // Params: id - unique tender ID, description - tender description
  // Returns: true if tender created successfully
  public shared(msg) func createTender(id: Text, description: Text) : async Bool {
    // Validate tender ID uniqueness and non-empty description
    if (id == "" or description == "") {
      return false;
    };
    if (tenders.get(id) != null) {
      return false;
    };
    let tender : Tender = {
      id = id;
      description = description;
      issuer = msg.caller;       // Caller is the issuer
      createdAt = Time.now();    // Current time as creation time
      status = #Open;           // Initial status is "Open"
    };
    tenders.put(id, tender);     // Store the tender in the map
    logEvent("Tender created with ID: " # id);
    true
  };

  // Submit a bid for a tender
  // Params: tenderId - ID of the tender, amount - bid amount
  // Returns: true if bid submitted successfully, false otherwise
  public shared(msg) func submitBid(tenderId: Text, amount: Nat) : async Bool {
    switch (tenders.get(tenderId)) {
      case (null) { false }; // Tender doesn't exist
      case (?tender) {
        if (tender.status != #Open) { return false }; // Only open tenders accept bids
        let bid : Bid = {
          tenderId = tenderId;
          bidder = msg.caller;     // Caller is the bidder
          amount = amount;
          submittedAt = Time.now(); // Current time as submission time
        };
        // Use composite key of tenderId, bidder principal text, and submission timestamp to allow multiple bids
        let submittedAtText = Int.toText(bid.submittedAt);
        switch (Nat.fromText(submittedAtText)) {
          case (?natVal) {
            let timestampText = Nat64.toText(Nat64.fromNat(natVal));
            bids.put(tenderId # "-" # Principal.toText(msg.caller) # "-" # timestampText, bid);
          };
          case (null) {
            // Fallback: use submittedAt as text directly (may cause key collisions)
            bids.put(tenderId # "-" # Principal.toText(msg.caller) # "-" # submittedAtText, bid);
          };
        };
        true
      };
    }
  };

  // Query all tenders (public access)
  // Returns: array of (tender ID, Tender) tuples
  public query func getTenders() : async [(Text, Tender)] {
    Iter.toArray(tenders.entries())
  };

  // Query bids for a specific tender
  // Params: tenderId - ID of the tender
  // Returns: array of Bid objects for the tender
  public query func getBids(tenderId: Text) : async [Bid] {
    let bidList = Iter.toArray(bids.entries());
    // Filter bids matching the tenderId
    let filteredBids = Array.filter(bidList, func ((id, bid): (Text, Bid)) : Bool { bid.tenderId == tenderId });
    // Map to extract Bid objects from (id, Bid) tuples
    Array.map(filteredBids, func ((id, bid): (Text, Bid)) : Bid { bid })
  };

  // Award tender to the lowest bid
  // Params: tenderId - ID of the tender
  // Returns: optional Principal of the winning bidder or null if no winner
  public shared(msg) func awardTender(tenderId: Text) : async ?Principal {
    switch (tenders.get(tenderId)) {
      case (null) { null }; // Tender not found
      case (?tender) {
        // Only issuer can award and tender must be open
        if (tender.issuer != msg.caller or tender.status != #Open) { return null };
        // Filter bids for the tender
        let tenderBids = Array.filter(Iter.toArray(bids.entries()), func ((id, bid): (Text, Bid)) : Bool { bid.tenderId == tenderId });
        if (tenderBids.size() == 0) { return null }; // No bids
        // Find the lowest bid using foldLeft
        let lowestBid = Array.foldLeft<(Text, Bid), ?Bid>(
          tenderBids,
          null,
          func (min, (_, bid)) {
            switch (min) {
              case (null) { ?bid };
              case (?currentMin) { if (bid.amount < currentMin.amount) { ?bid } else { ?currentMin } };
            }
          }
        );
        switch (lowestBid) {
          case (null) { null };
          case (?bid) {
            // Update tender status to "Closed"
            tenders.put(tenderId, { tender with status = #Awarded });
            logEvent("Tender awarded and closed with ID: " # tenderId);
            // Return the winning bidder principal
            ?bid.bidder
          };
        }
      };
    }
  };

  // Query awarded tenders with winning bid and amount
  public query func getAwardedTenders() : async [AwardedTender] {
    let allTenders = Iter.toArray(tenders.entries());
    let awardedTenders = Array.filter(allTenders, func ((id, tender): (Text, Tender)) : Bool { tender.status == #Awarded });
    Array.map(awardedTenders, func ((id, tender): (Text, Tender)) : AwardedTender {
      // Find winning bid for tender
      let tenderBids = Array.filter(Iter.toArray(bids.entries()), func ((bidId, bid): (Text, Bid)) : Bool { bid.tenderId == id });
      let lowestBid = Array.foldLeft<(Text, Bid), ?Bid>(
        tenderBids,
        null,
        func (min, (_, bid)) {
          switch (min) {
            case (null) { ?bid };
            case (?currentMin) { if (bid.amount < currentMin.amount) { ?bid } else { ?currentMin } };
          }
        }
      );
      switch (lowestBid) {
        case (null) { { id = id; tender = tender; winningBid = { tenderId = id; bidder = Principal.fromText(""); amount = 0; submittedAt = 0 } } };
        case (?bid) { { id = id; tender = tender; winningBid = bid } };
      }
    })
  };
};
