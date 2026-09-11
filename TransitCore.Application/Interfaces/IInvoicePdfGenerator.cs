using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IInvoicePdfGenerator
{
    byte[] Generate(InvoiceDetailDto invoice);
}
