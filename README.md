# Procurement Platform

This is a decentralized procurement platform backend implemented in Motoko for the Internet Computer. It allows users to create tenders, submit bids, award tenders to the lowest bidder, and query tenders and bids.

## Features

- Create new tenders with unique IDs and descriptions.
- Submit bids for open tenders with bid amount and timestamp.
- Award tenders to the lowest bid by the issuer.
- Query all tenders, bids for a tender, and awarded tenders with winning bids.
- Tender status management: Open, Closed, Awarded.

## Technologies

- Motoko programming language
- Internet Computer (DFINITY) canisters
- Motoko standard library modules: HashMap, Iter, Array, Time, Principal, Nat, Nat64, Int, Text

## Setup and Deployment

1. Install DFINITY SDK (dfx) from https://sdk.dfinity.org/
2. Clone this repository.
3. Navigate to the project directory.
4. Build and deploy the canisters:

```bash
dfx deploy
```

## Usage

The backend exposes the following main functions:

- `createTender(id: Text, description: Text): async Bool`  
  Create a new tender with the given ID and description.

- `submitBid(tenderId: Text, amount: Nat): async Bool`  
  Submit a bid for the specified tender with the bid amount.

- `awardTender(tenderId: Text): async ?Principal`  
  Award the tender to the lowest bid. Only the issuer can award.

- `getTenders(): async [(Text, Tender)]`  
  Query all tenders.

- `getBids(tenderId: Text): async [Bid]`  
  Query all bids for a specific tender.

- `getAwardedTenders(): async [AwardedTender]`  
  Query all awarded tenders with winning bids.

## Data Types

- `Tender`  
  Contains id, description, issuer, creation time, and status.

- `Bid`  
  Contains tenderId, bidder, amount, and submission time.

- `AwardedTender`  
  Contains tender id, tender details, and winning bid.

## Notes

- Multiple bids per bidder are supported using composite keys including timestamps.
- Tender status transitions from "Open" to "Closed" upon awarding.
- The project uses Motoko standard library modules extensively.

## License

This project is licensed under the MIT License.

## Contact

For questions or contributions, please contact the project maintainer.
OCHIENG BOSTONE - Backend Developer
