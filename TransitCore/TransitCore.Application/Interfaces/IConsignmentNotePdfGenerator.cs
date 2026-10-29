using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IConsignmentNotePdfGenerator
{
    byte[] Generate(ConsignmentNoteDetailDto consignmentNote);
}
