using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Buidoananhviet.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAttendanceFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "DeviceId",
                table: "Attendances",
                type: "nvarchar(450)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CheckOutDeviceId",
                table: "Attendances",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CheckOutDistanceMeters",
                table: "Attendances",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CheckOutLatitude",
                table: "Attendances",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CheckOutLongitude",
                table: "Attendances",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "GrossPay",
                table: "Attendances",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTime>(
                name: "WorkDate",
                table: "Attendances",
                type: "date",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.CreateIndex(
                name: "IX_Attendances_DeviceId_WorkDate",
                table: "Attendances",
                columns: new[] { "DeviceId", "WorkDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Attendances_UserId_ShiftId_WorkDate",
                table: "Attendances",
                columns: new[] { "UserId", "ShiftId", "WorkDate" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Attendances_DeviceId_WorkDate",
                table: "Attendances");

            migrationBuilder.DropIndex(
                name: "IX_Attendances_UserId_ShiftId_WorkDate",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "CheckOutDeviceId",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "CheckOutDistanceMeters",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "CheckOutLatitude",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "CheckOutLongitude",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "GrossPay",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "WorkDate",
                table: "Attendances");

            migrationBuilder.AlterColumn<string>(
                name: "DeviceId",
                table: "Attendances",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)",
                oldNullable: true);
        }
    }
}
