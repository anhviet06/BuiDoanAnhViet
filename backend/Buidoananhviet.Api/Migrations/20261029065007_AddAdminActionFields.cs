using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Buidoananhviet.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminActionFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AdminAction",
                table: "Attendances",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AdminActionAt",
                table: "Attendances",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "AdminActionByUserId",
                table: "Attendances",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AdminNote",
                table: "Attendances",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AdminAction",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "AdminActionAt",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "AdminActionByUserId",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "AdminNote",
                table: "Attendances");
        }
    }
}
