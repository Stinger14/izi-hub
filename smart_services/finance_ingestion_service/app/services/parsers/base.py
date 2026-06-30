from abc import ABC, abstractmethod
from app.modules.finance.schemas import ParsedBankAlert


class EmailParser(ABC):
    @abstractmethod
    def can_parse(self, sender: str, subject: str, body: str) -> bool:
        pass

    @abstractmethod
    def parse(self, sender: str, subject: str, body: str) -> ParsedBankAlert:
        pass
